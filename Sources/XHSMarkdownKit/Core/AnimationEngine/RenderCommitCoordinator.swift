import UIKit

public enum RenderAnimationMode {
    case instant
    case dualPhase
}

public struct RenderFrame {
    public let version: Int
    public let previousScene: RenderScene
    public let targetScene: RenderScene
    public let diff: SceneDiff
    public let delta: SceneDelta
    public let executionPlan: RenderExecutionPlan?
    public let isFinal: Bool
    public let animationMode: RenderAnimationMode
    public let defaultEffectKey: AnimationEffectKey
    public let entityAppearanceMode: ContentEntityAppearanceMode
    public let unitsPerSecond: Int

    public init(
        version: Int,
        previousScene: RenderScene,
        targetScene: RenderScene,
        diff: SceneDiff,
        delta: SceneDelta,
        executionPlan: RenderExecutionPlan? = nil,
        isFinal: Bool,
        animationMode: RenderAnimationMode,
        defaultEffectKey: AnimationEffectKey,
        entityAppearanceMode: ContentEntityAppearanceMode,
        unitsPerSecond: Int
    ) {
        self.version = version
        self.previousScene = previousScene
        self.targetScene = targetScene
        self.diff = diff
        self.delta = delta
        self.executionPlan = executionPlan
        self.isFinal = isFinal
        self.animationMode = animationMode
        self.defaultEffectKey = defaultEffectKey
        self.entityAppearanceMode = entityAppearanceMode
        self.unitsPerSecond = max(1, unitsPerSecond)
    }
}

public final class RenderCommitCoordinator {
    public var concurrencyPolicy: AnimationConcurrencyPolicy = .fullyOrdered
    public var onProgress: ((AnimationProgress) -> Void)?
    public var onAnimationComplete: (() -> Void)?
    public var onHeightChange: ((CGFloat) -> Void)?

    private struct ContentTrack {
        let entityId: String
        let inserted: Bool
        let revealStartUnits: Int
        let stableStartUnits: Int
        let targetUnits: Int
        let deltaUnits: Int
    }

    private struct StageWork {
        let stage: RenderExecutionPlan.Stage
        let tracks: [ContentTrack]
        let totalDeltaUnits: Int
    }

    private final class ActiveTransaction {
        let frame: RenderFrame
        let stageWorks: [StageWork]
        let totalDeltaUnits: Int

        var stageIndex: Int = 0
        var completedDeltaUnits: Int = 0

        var currentTracks: [ContentTrack] = []
        var currentStageDeltaUnits: Int = 0
        var currentStagePhase: AnimationPhase = .content
        var currentStageEffectKey: AnimationEffectKey = .typing

        var displayLink: CADisplayLink?
        var stageStartTimestamp: CFTimeInterval?
        var cancellationToken: Int
        var hiddenInsertedEntityIDs: Set<String>

        init(
            frame: RenderFrame,
            stageWorks: [StageWork],
            totalDeltaUnits: Int,
            hiddenInsertedEntityIDs: Set<String>,
            cancellationToken: Int
        ) {
            self.frame = frame
            self.stageWorks = stageWorks
            self.totalDeltaUnits = totalDeltaUnits
            self.hiddenInsertedEntityIDs = hiddenInsertedEntityIDs
            self.cancellationToken = cancellationToken
        }
    }

    private let layoutCoordinator = LayoutCoordinator(changeThreshold: 1)
    private let applyScene: (RenderScene) -> Void
    private let viewForEntity: (String) -> UIView?
    private let measureHeight: () -> CGFloat
    private let animateStructuralChanges: ([StructuralSceneChange]) -> Void
    private let animationStateStore: any AnimationStateBackingStore

    private var activeTransaction: ActiveTransaction?
    private var pendingQueue: [RenderFrame] = []
    private var cancellationToken: Int = 0
    private var nextExpectedVersion: Int = 1

    public init(
        applyScene: @escaping (RenderScene) -> Void,
        viewForEntity: @escaping (String) -> UIView?,
        measureHeight: @escaping () -> CGFloat,
        animateStructuralChanges: @escaping ([StructuralSceneChange]) -> Void,
        animationStateStore: any AnimationStateBackingStore
    ) {
        self.applyScene = applyScene
        self.viewForEntity = viewForEntity
        self.measureHeight = measureHeight
        self.animateStructuralChanges = animateStructuralChanges
        self.animationStateStore = animationStateStore
    }

    public func submit(_ frame: RenderFrame) {
        if let _ = activeTransaction {
            switch concurrencyPolicy {
            case .latestWins:
                pendingQueue.removeAll()
                cancelActiveTransaction()
                start(frame)

            case .fullyOrdered:
                guard frame.version >= nextExpectedVersion else { return }
                pendingQueue.append(frame)
                pendingQueue.sort { $0.version < $1.version }
            }
            return
        }

        if concurrencyPolicy == .fullyOrdered, frame.version < nextExpectedVersion {
            return
        }
        start(frame)
    }

    public func finishAll() {
        pendingQueue.removeAll()
        guard let active = activeTransaction else { return }
        active.displayLink?.invalidate()
        active.displayLink = nil
        applyScene(active.frame.targetScene)
        applyFullyVisibleState(to: active.frame.targetScene, elapsedMilliseconds: 0, version: active.frame.version)
        layoutCoordinator.publishFrame(
            version: active.frame.version,
            phase: .completed,
            displayedUnits: active.totalDeltaUnits,
            totalUnits: active.totalDeltaUnits,
            elapsedMilliseconds: 0,
            isRunning: false,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )
        activeTransaction = nil
        finalize(version: active.frame.version)
    }

    private func start(_ frame: RenderFrame) {
        prepareProgressStore(for: frame.targetScene)

        if frame.animationMode == .instant || frame.delta.isEmpty {
            applyScene(frame.targetScene)
            applyFullyVisibleState(to: frame.targetScene, elapsedMilliseconds: 0, version: frame.version)
            publishCompletedProgress(for: frame)
            finalize(version: frame.version)
            return
        }

        let stageWorks = makeStageWorks(for: frame)
        let totalDelta = stageWorks.reduce(0) { $0 + $1.totalDeltaUnits }
        if totalDelta <= 0 {
            applyScene(frame.targetScene)
            applyFullyVisibleState(to: frame.targetScene, elapsedMilliseconds: 0, version: frame.version)
            publishCompletedProgress(for: frame)
            finalize(version: frame.version)
            return
        }

        let hiddenInsertedEntityIDs = initialHiddenInsertedEntityIDs(for: frame, stageWorks: stageWorks)
        applyProjectedScene(
            targetScene: frame.targetScene,
            hiddenInsertedEntityIDs: hiddenInsertedEntityIDs
        )

        guard !stageWorks.isEmpty else {
            applyScene(frame.targetScene)
            applyFullyVisibleState(to: frame.targetScene, elapsedMilliseconds: 0, version: frame.version)
            publishCompletedProgress(for: frame)
            finalize(version: frame.version)
            return
        }

        cancellationToken += 1
        let transaction = ActiveTransaction(
            frame: frame,
            stageWorks: stageWorks,
            totalDeltaUnits: totalDelta,
            hiddenInsertedEntityIDs: hiddenInsertedEntityIDs,
            cancellationToken: cancellationToken
        )
        activeTransaction = transaction
        beginCurrentStage(for: transaction, elapsedMilliseconds: 0)
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        guard let transaction = activeTransaction,
              transaction.displayLink === displayLink else {
            displayLink.invalidate()
            return
        }

        if transaction.cancellationToken != cancellationToken {
            displayLink.invalidate()
            return
        }

        guard transaction.currentStageDeltaUnits > 0, !transaction.currentTracks.isEmpty else {
            displayLink.invalidate()
            transaction.displayLink = nil
            transaction.stageIndex += 1
            beginCurrentStage(for: transaction, elapsedMilliseconds: 0)
            return
        }

        let start: CFTimeInterval
        if let existing = transaction.stageStartTimestamp {
            start = existing
        } else {
            transaction.stageStartTimestamp = displayLink.timestamp
            start = displayLink.timestamp
        }

        let elapsedSeconds = max(0, displayLink.timestamp - start)
        let elapsedMilliseconds = Int((elapsedSeconds * 1000).rounded(.down))
        let progressedUnits = min(
            transaction.currentStageDeltaUnits,
            Int((elapsedSeconds * Double(transaction.frame.unitsPerSecond)).rounded(.down))
        )

        applyTracks(
            tracks: transaction.currentTracks,
            progressedUnits: progressedUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            targetScene: transaction.frame.targetScene,
            effectKey: transaction.currentStageEffectKey,
            appearanceMode: transaction.frame.entityAppearanceMode,
            version: transaction.frame.version,
            transaction: transaction
        )

        layoutCoordinator.publishFrame(
            version: transaction.frame.version,
            phase: transaction.currentStagePhase,
            displayedUnits: transaction.completedDeltaUnits + progressedUnits,
            totalUnits: transaction.totalDeltaUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            isRunning: transaction.completedDeltaUnits + progressedUnits < transaction.totalDeltaUnits,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )

        if progressedUnits >= transaction.currentStageDeltaUnits {
            displayLink.invalidate()
            transaction.displayLink = nil
            applyTracks(
                tracks: transaction.currentTracks,
                progressedUnits: transaction.currentStageDeltaUnits,
                elapsedMilliseconds: elapsedMilliseconds,
                targetScene: transaction.frame.targetScene,
                effectKey: transaction.currentStageEffectKey,
                appearanceMode: transaction.frame.entityAppearanceMode,
                version: transaction.frame.version,
                transaction: transaction
            )
            transaction.completedDeltaUnits += transaction.currentStageDeltaUnits
            transaction.stageIndex += 1
            beginCurrentStage(for: transaction, elapsedMilliseconds: elapsedMilliseconds)
        }
    }

    private func finalize(version: Int) {
        nextExpectedVersion = max(nextExpectedVersion, version + 1)
        onAnimationComplete?()

        if concurrencyPolicy == .fullyOrdered, !pendingQueue.isEmpty {
            let next = pendingQueue.removeFirst()
            start(next)
        }
    }

    private func publishCompletedProgress(for frame: RenderFrame) {
        layoutCoordinator.publishFrame(
            version: frame.version,
            phase: .completed,
            displayedUnits: 0,
            totalUnits: 0,
            elapsedMilliseconds: 0,
            isRunning: false,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )
    }

    private func cancelActiveTransaction() {
        guard let transaction = activeTransaction else { return }
        transaction.displayLink?.invalidate()
        transaction.displayLink = nil
        activeTransaction = nil
    }

    private func makeTracks(
        _ contentChanges: [ContentSceneChange],
        targetScene: RenderScene,
        progressSnapshot: inout [AnimationEntityKey: AnimationEntityProgressState]
    ) -> [ContentTrack] {
        contentChanges.compactMap { change in
            guard let node = targetScene.componentNodeByID(change.entityId),
                  let reveal = node.component as? any RevealAnimatableComponent,
                  reveal.revealUnitCount > 0 else {
                return nil
            }

            let key = animationEntityKey(documentID: targetScene.documentId, entityID: change.entityId)
            let targetUnits = min(change.targetUnits, reveal.revealUnitCount)
            let existing = progressSnapshot[key]
            let revealStartUnits = min(
                targetUnits,
                max(0, existing?.displayedUnits ?? change.stableUnits)
            )
            let stableStartUnits = min(
                revealStartUnits,
                max(0, existing?.stableUnits ?? min(change.stableUnits, revealStartUnits))
            )
            let delta = max(0, targetUnits - revealStartUnits)
            guard delta > 0 else { return nil }

            return ContentTrack(
                entityId: change.entityId,
                inserted: change.inserted,
                revealStartUnits: revealStartUnits,
                stableStartUnits: stableStartUnits,
                targetUnits: targetUnits,
                deltaUnits: delta
            )
        }
    }

    private func applyTracks(
        tracks: [ContentTrack],
        progressedUnits: Int,
        elapsedMilliseconds: Int,
        targetScene: RenderScene,
        effectKey: AnimationEffectKey,
        appearanceMode: ContentEntityAppearanceMode,
        version: Int,
        transaction: ActiveTransaction? = nil
    ) {
        let allocations = allocatedDeltaUnits(
            progressedUnits: progressedUnits,
            tracks: tracks,
            appearanceMode: appearanceMode
        )
        let displayedUnits = tracks.enumerated().map { index, track in
            let consumed = allocations[index]
            return track.revealStartUnits + min(track.deltaUnits, consumed)
        }

        if let transaction {
            revealInsertedEntitiesIfNeeded(
                tracks: tracks,
                displayedUnits: displayedUnits,
                transaction: transaction
            )
        }

        for (index, track) in tracks.enumerated() {
            let displayed = displayedUnits[index]
            let consumedUnits = allocations[index]

            guard let node = targetScene.componentNodeByID(track.entityId),
                  let component = node.component as? any RevealAnimatableComponent,
                  let view = viewForEntity(track.entityId) else {
                continue
            }

            let stableUnits: Int
            if let appearance = component as? any AppearanceAnimatableComponent {
                // Once this entity's delta is fully consumed, it must be fully stable.
                // This prevents trailing glyph alpha from lingering when the next entity starts.
                if consumedUnits >= track.deltaUnits {
                    stableUnits = displayed
                } else {
                    let tail = tailRampUnits(
                        for: effectKey,
                        base: appearance.appearanceProfile.tailRampUnits
                    )
                    stableUnits = min(
                        displayed,
                        max(track.stableStartUnits, displayed - tail)
                    )
                }
            } else {
                stableUnits = displayed
            }

            let revealState = RevealState(
                displayedUnits: displayed,
                totalUnits: track.targetUnits,
                stableUnits: stableUnits,
                elapsedMilliseconds: elapsedMilliseconds
            )
            component.reveal(view: view, state: revealState)

            let key = animationEntityKey(documentID: targetScene.documentId, entityID: track.entityId)
            animationStateStore.setAnimationState(
                AnimationEntityProgressState(
                    displayedUnits: displayed,
                    stableUnits: stableUnits,
                    targetUnits: track.targetUnits,
                    lastVersion: version
                ),
                for: key
            )

            if let appearance = component as? any AppearanceAnimatableComponent {
                appearance.applyAppearance(
                    view: view,
                    state: AppearanceState(revealState: revealState)
                )
            }
        }
    }

    private func prepareProgressStore(for targetScene: RenderScene) {
        var revealUnitsByEntity: [String: Int] = [:]
        for node in targetScene.flattenRenderableNodes() {
            guard let reveal = node.component as? any RevealAnimatableComponent else { continue }
            revealUnitsByEntity[node.id] = max(0, reveal.revealUnitCount)
        }
        animationStateStore.prepareAnimationState(documentID: targetScene.documentId, revealUnitsByEntity: revealUnitsByEntity)
    }

    private func applyFullyVisibleState(to scene: RenderScene, elapsedMilliseconds: Int, version: Int) {
        for node in scene.flattenRenderableNodes() {
            guard let component = node.component as? any RevealAnimatableComponent else { continue }
            let totalUnits = max(0, component.revealUnitCount)

            animationStateStore.setAnimationState(
                AnimationEntityProgressState(
                    displayedUnits: totalUnits,
                    stableUnits: totalUnits,
                    targetUnits: totalUnits,
                    lastVersion: version
                ),
                for: animationEntityKey(documentID: scene.documentId, entityID: node.id)
            )

            guard let view = viewForEntity(node.id) else { continue }
            let revealState = RevealState(
                displayedUnits: totalUnits,
                totalUnits: totalUnits,
                stableUnits: totalUnits,
                elapsedMilliseconds: elapsedMilliseconds
            )
            component.reveal(view: view, state: revealState)
            if let appearance = component as? any AppearanceAnimatableComponent {
                appearance.applyAppearance(view: view, state: AppearanceState(revealState: revealState))
            }
        }
    }

    private func makeStageWorks(for frame: RenderFrame) -> [StageWork] {
        let stages = (frame.executionPlan?.stages ?? makeDefaultStages(delta: frame.delta, defaultEffectKey: frame.defaultEffectKey))
            .filter { !$0.isEmpty }
        guard !stages.isEmpty else { return [] }

        var works: [StageWork] = []
        var progressSnapshot = animationStateStore.animationStates(documentID: frame.targetScene.documentId)

        for stage in stages {
            let tracks = makeTracks(stage.contentChanges, targetScene: frame.targetScene, progressSnapshot: &progressSnapshot)
            for track in tracks {
                progressSnapshot[animationEntityKey(documentID: frame.targetScene.documentId, entityID: track.entityId)] = AnimationEntityProgressState(
                    displayedUnits: track.targetUnits,
                    stableUnits: track.targetUnits,
                    targetUnits: track.targetUnits,
                    lastVersion: frame.version
                )
            }
            works.append(StageWork(
                stage: stage,
                tracks: tracks,
                totalDeltaUnits: tracks.reduce(0) { $0 + $1.deltaUnits }
            ))
        }

        return works
    }

    private func makeDefaultStages(delta: SceneDelta, defaultEffectKey: AnimationEffectKey) -> [RenderExecutionPlan.Stage] {
        guard !delta.isEmpty else { return [] }

        var stages: [RenderExecutionPlan.Stage] = []
        if !delta.structuralChanges.isEmpty {
            stages.append(RenderExecutionPlan.Stage(
                id: "default.structure",
                phase: .structure,
                effectKey: .segmentFade,
                structuralChanges: delta.structuralChanges
            ))
        }
        if !delta.contentChanges.isEmpty {
            stages.append(RenderExecutionPlan.Stage(
                id: "default.content",
                phase: .content,
                effectKey: defaultEffectKey,
                contentChanges: delta.contentChanges
            ))
        }

        if stages.isEmpty {
            stages.append(RenderExecutionPlan.Stage(
                id: "default.fallback",
                phase: .content,
                effectKey: defaultEffectKey,
                structuralChanges: delta.structuralChanges,
                contentChanges: delta.contentChanges
            ))
        }
        return stages
    }

    private func beginCurrentStage(for transaction: ActiveTransaction, elapsedMilliseconds: Int) {
        guard let active = activeTransaction, active === transaction else { return }

        if transaction.stageIndex >= transaction.stageWorks.count {
            complete(transaction: transaction, elapsedMilliseconds: elapsedMilliseconds)
            return
        }

        let work = transaction.stageWorks[transaction.stageIndex]
        if !work.stage.structuralChanges.isEmpty {
            applyStructuralChanges(changes: work.stage.structuralChanges, effectKey: work.stage.effectKey)
        }

        transaction.currentTracks = work.tracks
        transaction.currentStageDeltaUnits = work.totalDeltaUnits
        transaction.currentStagePhase = work.stage.phase
        transaction.currentStageEffectKey = work.stage.effectKey
        transaction.stageStartTimestamp = nil

        if work.totalDeltaUnits <= 0 {
            layoutCoordinator.publishFrame(
                version: transaction.frame.version,
                phase: work.stage.phase,
                displayedUnits: transaction.completedDeltaUnits,
                totalUnits: transaction.totalDeltaUnits,
                elapsedMilliseconds: elapsedMilliseconds,
                isRunning: transaction.completedDeltaUnits < transaction.totalDeltaUnits || transaction.stageIndex < transaction.stageWorks.count - 1,
                measureHeight: measureHeight,
                onProgress: onProgress,
                onHeightChange: onHeightChange
            )
            transaction.stageIndex += 1
            beginCurrentStage(for: transaction, elapsedMilliseconds: elapsedMilliseconds)
            return
        }

        applyTracks(
            tracks: work.tracks,
            progressedUnits: 0,
            elapsedMilliseconds: elapsedMilliseconds,
            targetScene: transaction.frame.targetScene,
            effectKey: work.stage.effectKey,
            appearanceMode: transaction.frame.entityAppearanceMode,
            version: transaction.frame.version,
            transaction: transaction
        )

        layoutCoordinator.publishFrame(
            version: transaction.frame.version,
            phase: work.stage.phase,
            displayedUnits: transaction.completedDeltaUnits,
            totalUnits: transaction.totalDeltaUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            isRunning: true,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        transaction.displayLink = link
    }

    private func applyStructuralChanges(changes: [StructuralSceneChange], effectKey: AnimationEffectKey) {
        guard shouldAnimateStructuralChanges(for: effectKey) else { return }
        animateStructuralChanges(changes)
    }

    private func shouldAnimateStructuralChanges(for effectKey: AnimationEffectKey) -> Bool {
        effectKey == .segmentFade || effectKey == .streamingMask || effectKey == .maskReveal
    }

    private func tailRampUnits(for effectKey: AnimationEffectKey, base: Int) -> Int {
        let baseline = max(1, base)
        switch effectKey {
        case .instant:
            return 1
        case .streamingMask, .maskReveal:
            return max(baseline, 24)
        case .typing:
            return max(baseline, 12)
        case .segmentFade:
            return max(baseline, 8)
        default:
            return baseline
        }
    }

    private func complete(transaction: ActiveTransaction, elapsedMilliseconds: Int) {
        transaction.displayLink?.invalidate()
        transaction.displayLink = nil
        applyScene(transaction.frame.targetScene)
        applyFullyVisibleState(
            to: transaction.frame.targetScene,
            elapsedMilliseconds: elapsedMilliseconds,
            version: transaction.frame.version
        )
        layoutCoordinator.publishFrame(
            version: transaction.frame.version,
            phase: .completed,
            displayedUnits: transaction.totalDeltaUnits,
            totalUnits: transaction.totalDeltaUnits,
            elapsedMilliseconds: max(0, elapsedMilliseconds),
            isRunning: false,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )
        activeTransaction = nil
        finalize(version: transaction.frame.version)
    }

    private func animationEntityKey(documentID: String, entityID: String) -> AnimationEntityKey {
        AnimationEntityKey(documentId: documentID, entityId: entityID)
    }

    private func revealInsertedEntitiesIfNeeded(
        tracks: [ContentTrack],
        displayedUnits: [Int],
        transaction: ActiveTransaction
    ) {
        guard !tracks.isEmpty, !transaction.hiddenInsertedEntityIDs.isEmpty else { return }

        var revealedEntityIDs: [String] = []
        revealedEntityIDs.reserveCapacity(tracks.count)
        for (index, track) in tracks.enumerated() {
            guard track.inserted else { continue }
            guard displayedUnits[index] > 0 else { continue }
            guard transaction.hiddenInsertedEntityIDs.contains(track.entityId) else { continue }
            revealedEntityIDs.append(track.entityId)
        }

        guard !revealedEntityIDs.isEmpty else { return }
        transaction.hiddenInsertedEntityIDs.subtract(revealedEntityIDs)
        applyProjectedScene(
            targetScene: transaction.frame.targetScene,
            hiddenInsertedEntityIDs: transaction.hiddenInsertedEntityIDs
        )
    }

    private func initialHiddenInsertedEntityIDs(for frame: RenderFrame, stageWorks: [StageWork]) -> Set<String> {
        var hidden = Set(
            frame.delta.structuralChanges.compactMap { change in
                change.kind == .insert ? change.entityId : nil
            }
        )
        hidden.formUnion(
            frame.delta.contentChanges.compactMap { change in
                change.inserted ? change.entityId : nil
            }
        )
        guard !hidden.isEmpty else { return [] }

        let progressByEntity = animationStateStore.animationStates(documentID: frame.targetScene.documentId)
        for entityID in Array(hidden) {
            let key = animationEntityKey(documentID: frame.targetScene.documentId, entityID: entityID)
            if let progress = progressByEntity[key], progress.displayedUnits > 0 {
                hidden.remove(entityID)
            }
        }

        for work in stageWorks {
            for track in work.tracks where track.inserted && track.revealStartUnits > 0 {
                hidden.remove(track.entityId)
            }
        }
        return hidden
    }

    private func applyProjectedScene(targetScene: RenderScene, hiddenInsertedEntityIDs: Set<String>) {
        applyScene(projectedScene(targetScene, hidingInsertedEntityIDs: hiddenInsertedEntityIDs))
    }

    private func projectedScene(_ scene: RenderScene, hidingInsertedEntityIDs: Set<String>) -> RenderScene {
        guard !hidingInsertedEntityIDs.isEmpty else { return scene }

        func projectNode(_ node: RenderScene.Node, parentHidden: Bool) -> RenderScene.Node {
            let hidden = parentHidden || hidingInsertedEntityIDs.contains(node.id)
            let projectedChildren = node.children.map { child in
                projectNode(child, parentHidden: hidden)
            }
            return RenderScene.Node(
                id: node.id,
                kind: node.kind,
                component: hidden ? nil : node.component,
                children: projectedChildren,
                spacingAfter: hidden ? 0 : node.spacingAfter,
                metadata: node.metadata
            )
        }

        return RenderScene(
            documentId: scene.documentId,
            nodes: scene.nodes.map { projectNode($0, parentHidden: false) },
            metadata: scene.metadata
        )
    }

    private func allocatedDeltaUnits(
        progressedUnits: Int,
        tracks: [ContentTrack],
        appearanceMode: ContentEntityAppearanceMode
    ) -> [Int] {
        guard !tracks.isEmpty else { return [] }
        let target = max(0, progressedUnits)

        switch appearanceMode {
        case .sequential:
            var remaining = target
            return tracks.map { track in
                let consumed = min(track.deltaUnits, remaining)
                remaining -= consumed
                return consumed
            }

        case .simultaneous:
            let total = max(1, tracks.reduce(0) { $0 + $1.deltaUnits })
            var baseAllocations: [Int] = []
            var fractions: [(index: Int, fraction: Double)] = []
            baseAllocations.reserveCapacity(tracks.count)
            fractions.reserveCapacity(tracks.count)

            var allocated = 0
            for (index, track) in tracks.enumerated() {
                let raw = Double(target) * Double(track.deltaUnits) / Double(total)
                let floored = min(track.deltaUnits, Int(raw.rounded(.down)))
                baseAllocations.append(floored)
                allocated += floored
                fractions.append((index: index, fraction: raw - Double(floored)))
            }

            var remainder = min(target, total) - allocated
            if remainder > 0 {
                fractions.sort { lhs, rhs in
                    if lhs.fraction != rhs.fraction {
                        return lhs.fraction > rhs.fraction
                    }
                    return lhs.index < rhs.index
                }
                for item in fractions where remainder > 0 {
                    let index = item.index
                    guard baseAllocations[index] < tracks[index].deltaUnits else { continue }
                    baseAllocations[index] += 1
                    remainder -= 1
                }
            }
            return baseAllocations
        }
    }
}
