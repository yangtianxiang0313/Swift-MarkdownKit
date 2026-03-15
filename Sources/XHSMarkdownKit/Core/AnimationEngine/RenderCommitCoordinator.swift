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
    public let isFinal: Bool
    public let animationMode: RenderAnimationMode
    public let unitsPerSecond: Int

    public init(
        version: Int,
        previousScene: RenderScene,
        targetScene: RenderScene,
        diff: SceneDiff,
        delta: SceneDelta,
        isFinal: Bool,
        animationMode: RenderAnimationMode,
        unitsPerSecond: Int
    ) {
        self.version = version
        self.previousScene = previousScene
        self.targetScene = targetScene
        self.diff = diff
        self.delta = delta
        self.isFinal = isFinal
        self.animationMode = animationMode
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
        let revealStartUnits: Int
        let stableStartUnits: Int
        let targetUnits: Int
        let deltaUnits: Int
    }

    private final class ActiveTransaction {
        let frame: RenderFrame
        let tracks: [ContentTrack]
        let totalDeltaUnits: Int
        var displayLink: CADisplayLink?
        var startTimestamp: CFTimeInterval?
        var cancellationToken: Int

        init(frame: RenderFrame, tracks: [ContentTrack], totalDeltaUnits: Int, cancellationToken: Int) {
            self.frame = frame
            self.tracks = tracks
            self.totalDeltaUnits = totalDeltaUnits
            self.cancellationToken = cancellationToken
        }
    }

    private let layoutCoordinator = LayoutCoordinator(changeThreshold: 1)
    private let applyScene: (RenderScene) -> Void
    private let viewForEntity: (String) -> UIView?
    private let measureHeight: () -> CGFloat
    private let animateStructuralChanges: ([StructuralSceneChange]) -> Void

    private var activeTransaction: ActiveTransaction?
    private var pendingQueue: [RenderFrame] = []
    private var cancellationToken: Int = 0
    private var nextExpectedVersion: Int = 1
    private var displayedUnitsByEntity: [String: Int] = [:]
    private var opaqueUnitsByEntity: [String: Int] = [:]

    public init(
        applyScene: @escaping (RenderScene) -> Void,
        viewForEntity: @escaping (String) -> UIView?,
        measureHeight: @escaping () -> CGFloat,
        animateStructuralChanges: @escaping ([StructuralSceneChange]) -> Void
    ) {
        self.applyScene = applyScene
        self.viewForEntity = viewForEntity
        self.measureHeight = measureHeight
        self.animateStructuralChanges = animateStructuralChanges
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
        complete(transaction: active, elapsedMilliseconds: 0, forceFinal: true)
    }

    private func start(_ frame: RenderFrame) {
        syncDisplayedState(to: frame.targetScene)

        if frame.animationMode == .instant || frame.delta.isEmpty {
            applyScene(frame.targetScene)
            applyFullyVisibleState(to: frame.targetScene, elapsedMilliseconds: 0)
            publishCompletedProgress(for: frame)
            finalize(version: frame.version)
            return
        }

        applyScene(frame.targetScene)
        animateStructuralChanges(frame.delta.structuralChanges)

        let tracks = makeTracks(frame.delta.contentChanges, targetScene: frame.targetScene)
        let totalDelta = tracks.reduce(0) { $0 + $1.deltaUnits }

        layoutCoordinator.publishFrame(
            version: frame.version,
            phase: .structure,
            displayedUnits: 0,
            totalUnits: totalDelta,
            elapsedMilliseconds: 0,
            isRunning: true,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )

        guard totalDelta > 0 else {
            publishCompletedProgress(for: frame)
            finalize(version: frame.version)
            return
        }

        cancellationToken += 1
        let transaction = ActiveTransaction(
            frame: frame,
            tracks: tracks,
            totalDeltaUnits: totalDelta,
            cancellationToken: cancellationToken
        )
        activeTransaction = transaction

        applyTracks(tracks: tracks, progressedUnits: 0, elapsedMilliseconds: 0, targetScene: frame.targetScene)

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        transaction.displayLink = link
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

        let start: CFTimeInterval
        if let existing = transaction.startTimestamp {
            start = existing
        } else {
            transaction.startTimestamp = displayLink.timestamp
            start = displayLink.timestamp
        }

        let elapsedSeconds = max(0, displayLink.timestamp - start)
        let elapsedMilliseconds = Int((elapsedSeconds * 1000).rounded(.down))
        let progressedUnits = min(
            transaction.totalDeltaUnits,
            Int((elapsedSeconds * Double(transaction.frame.unitsPerSecond)).rounded(.down))
        )

        applyTracks(
            tracks: transaction.tracks,
            progressedUnits: progressedUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            targetScene: transaction.frame.targetScene
        )

        layoutCoordinator.publishFrame(
            version: transaction.frame.version,
            phase: .content,
            displayedUnits: progressedUnits,
            totalUnits: transaction.totalDeltaUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            isRunning: progressedUnits < transaction.totalDeltaUnits,
            measureHeight: measureHeight,
            onProgress: onProgress,
            onHeightChange: onHeightChange
        )

        if progressedUnits >= transaction.totalDeltaUnits {
            complete(transaction: transaction, elapsedMilliseconds: elapsedMilliseconds, forceFinal: false)
        }
    }

    private func complete(transaction: ActiveTransaction, elapsedMilliseconds: Int, forceFinal: Bool) {
        transaction.displayLink?.invalidate()
        transaction.displayLink = nil

        applyTracks(
            tracks: transaction.tracks,
            progressedUnits: transaction.totalDeltaUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            targetScene: transaction.frame.targetScene
        )
        applyFullyVisibleState(
            to: transaction.frame.targetScene,
            elapsedMilliseconds: elapsedMilliseconds
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

        if forceFinal {
            return
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

    private func makeTracks(_ contentChanges: [ContentSceneChange], targetScene: RenderScene) -> [ContentTrack] {
        contentChanges.compactMap { change in
            guard let node = targetScene.componentNodeByID(change.entityId),
                  let reveal = node.component as? any RevealAnimatableComponent,
                  reveal.revealUnitCount > 0 else {
                return nil
            }

            let targetUnits = min(change.targetUnits, reveal.revealUnitCount)
            let revealStartUnits = min(
                targetUnits,
                max(0, displayedUnitsByEntity[change.entityId] ?? change.stableUnits)
            )
            let stableStartUnits = min(
                revealStartUnits,
                max(0, opaqueUnitsByEntity[change.entityId] ?? min(change.stableUnits, revealStartUnits))
            )
            let delta = max(0, targetUnits - revealStartUnits)
            guard delta > 0 else { return nil }

            return ContentTrack(
                entityId: change.entityId,
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
        targetScene: RenderScene
    ) {
        var remaining = max(0, progressedUnits)

        for track in tracks {
            let consumed = min(track.deltaUnits, remaining)
            remaining -= consumed
            let displayed = track.revealStartUnits + consumed

            guard let node = targetScene.componentNodeByID(track.entityId),
                  let component = node.component as? any RevealAnimatableComponent,
                  let view = viewForEntity(track.entityId) else {
                continue
            }

            let stableUnits: Int
            if let appearance = component as? any AppearanceAnimatableComponent {
                let tail = max(1, appearance.appearanceProfile.tailRampUnits)
                stableUnits = min(
                    displayed,
                    max(track.stableStartUnits, displayed - tail)
                )
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
            displayedUnitsByEntity[track.entityId] = displayed
            opaqueUnitsByEntity[track.entityId] = stableUnits

            if let appearance = component as? any AppearanceAnimatableComponent {
                appearance.applyAppearance(
                    view: view,
                    state: AppearanceState(revealState: revealState)
                )
            }
        }
    }

    private func syncDisplayedState(to targetScene: RenderScene) {
        var revealUnitsByID: [String: Int] = [:]
        for node in targetScene.flattenRenderableNodes() {
            guard let reveal = node.component as? any RevealAnimatableComponent else { continue }
            revealUnitsByID[node.id] = max(0, reveal.revealUnitCount)
        }

        displayedUnitsByEntity = displayedUnitsByEntity.filter { revealUnitsByID[$0.key] != nil }
        opaqueUnitsByEntity = opaqueUnitsByEntity.filter { revealUnitsByID[$0.key] != nil }
        for (id, maxUnits) in revealUnitsByID {
            guard let existing = displayedUnitsByEntity[id] else { continue }
            displayedUnitsByEntity[id] = min(maxUnits, max(0, existing))
            if let stable = opaqueUnitsByEntity[id] {
                opaqueUnitsByEntity[id] = min(displayedUnitsByEntity[id] ?? maxUnits, max(0, stable))
            }
        }
    }

    private func applyFullyVisibleState(to scene: RenderScene, elapsedMilliseconds: Int) {
        for node in scene.flattenRenderableNodes() {
            guard let component = node.component as? any RevealAnimatableComponent else { continue }
            let totalUnits = max(0, component.revealUnitCount)
            displayedUnitsByEntity[node.id] = totalUnits
            opaqueUnitsByEntity[node.id] = totalUnits

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
}
