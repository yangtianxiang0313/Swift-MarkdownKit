import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public protocol ContractAnimationPlanMapping {
    func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        oldScene: RenderScene,
        newScene: RenderScene,
        diff: SceneDiff,
        defaultEffectKey: AnimationEffectKey
    ) -> AnimationPlan
}

public struct DefaultContractAnimationPlanMapper: ContractAnimationPlanMapping {
    public init() {}

    public func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        oldScene: RenderScene,
        newScene: RenderScene,
        diff: SceneDiff,
        defaultEffectKey: AnimationEffectKey
    ) -> AnimationPlan {
        guard !diff.isEmpty else { return .empty }

        let phases = orderedPhases(from: contractPlan.timeline)
        let tracksByID = Dictionary(uniqueKeysWithValues: contractPlan.timeline.tracks.map { ($0.id, $0) })

        var remaining = diff.changes
        var steps: [AnimationStep] = []
        var previousStepID: AnimationStep.StepID?

        for (index, phase) in phases.enumerated() {
            let supportedKinds = changeKinds(for: phase, tracksByID: tracksByID)
            guard !supportedKinds.isEmpty else { continue }

            let phaseChanges = takeChanges(from: &remaining, matching: supportedKinds)
            guard !phaseChanges.isEmpty else { continue }

            let stepID = "contract.\(sanitized(phase.id)).\(index)"
            let entityIDs = phaseChanges.map(\.entityId)

            steps.append(AnimationStep(
                id: stepID,
                dependencies: previousStepID.map { [$0] } ?? [],
                effectKey: effectKey(for: phase, fallback: defaultEffectKey),
                entityIDs: entityIDs,
                fromScene: oldScene,
                toScene: newScene
            ))

            previousStepID = stepID
        }

        if !remaining.isEmpty {
            steps.append(AnimationStep(
                id: "contract.remainder",
                dependencies: previousStepID.map { [$0] } ?? [],
                effectKey: defaultEffectKey,
                entityIDs: remaining.map(\.entityId),
                fromScene: oldScene,
                toScene: newScene
            ))
            previousStepID = "contract.remainder"
        }

        if steps.isEmpty {
            steps = [AnimationStep(
                id: "contract.fallback",
                effectKey: defaultEffectKey,
                entityIDs: diff.changes.map(\.entityId),
                fromScene: oldScene,
                toScene: newScene
            )]
            previousStepID = "contract.fallback"
        }

        if steps.last?.toScene != newScene {
            steps.append(AnimationStep(
                id: "contract.finalize",
                dependencies: previousStepID.map { [$0] } ?? [],
                effectKey: .instant,
                entityIDs: newScene.entityIDs,
                fromScene: oldScene,
                toScene: newScene
            ))
        }

        return AnimationPlan(steps: steps)
    }
}

private extension DefaultContractAnimationPlanMapper {
    func changeKinds(
        for phase: MarkdownContract.TimelinePhase,
        tracksByID: [String: MarkdownContract.TimelineTrack]
    ) -> Set<SceneChangeKind> {
        var result = Set<SceneChangeKind>(phase.trackIds.compactMap { trackID in
            guard let track = tracksByID[trackID] else { return nil }
            guard case let .string(raw)? = track.metadata["changeType"] else { return nil }
            return SceneChangeKind(rawValue: raw)
        })

        if !result.isEmpty {
            return result
        }

        let name = phase.name.lowercased()
        if name.contains("structure") {
            result.formUnion([.insert, .remove, .move])
        }
        if name.contains("content") || name.contains("update") {
            result.insert(.update)
        }
        if name.contains("insert") {
            result.insert(.insert)
        }
        if name.contains("remove") {
            result.insert(.remove)
        }
        if name.contains("move") {
            result.insert(.move)
        }
        return result
    }

    func orderedPhases(from timeline: MarkdownContract.TimelineGraph) -> [MarkdownContract.TimelinePhase] {
        guard !timeline.phases.isEmpty else { return [] }

        let phaseIndex = Dictionary(uniqueKeysWithValues: timeline.phases.enumerated().map { ($0.element.id, $0.offset) })
        var indegree = Dictionary(uniqueKeysWithValues: timeline.phases.map { ($0.id, 0) })
        var adjacency: [String: Set<String>] = [:]

        for constraint in timeline.constraints where constraint.kind.lowercased() == "after" {
            guard indegree[constraint.from] != nil, indegree[constraint.to] != nil else { continue }
            if adjacency[constraint.from, default: []].insert(constraint.to).inserted {
                indegree[constraint.to, default: 0] += 1
            }
        }

        var ready = timeline.phases
            .map(\.id)
            .filter { indegree[$0] == 0 }
            .sorted { (phaseIndex[$0] ?? .max) < (phaseIndex[$1] ?? .max) }
        var orderedIDs: [String] = []

        while !ready.isEmpty {
            let current = ready.removeFirst()
            orderedIDs.append(current)

            for next in adjacency[current] ?? [] {
                guard let value = indegree[next] else { continue }
                let reduced = value - 1
                indegree[next] = reduced
                if reduced == 0 {
                    ready.append(next)
                }
            }

            ready.sort { (phaseIndex[$0] ?? .max) < (phaseIndex[$1] ?? .max) }
        }

        if orderedIDs.count != timeline.phases.count {
            return timeline.phases
        }

        let phaseByID = Dictionary(uniqueKeysWithValues: timeline.phases.map { ($0.id, $0) })
        return orderedIDs.compactMap { phaseByID[$0] }
    }

    func takeChanges(from changes: inout [SceneChange], matching kinds: Set<SceneChangeKind>) -> [SceneChange] {
        guard !kinds.isEmpty else { return [] }

        var matched: [SceneChange] = []
        var remained: [SceneChange] = []

        for change in changes {
            if kinds.contains(change.kind) {
                matched.append(change)
            } else {
                remained.append(change)
            }
        }

        changes = remained
        return matched
    }

    func effectKey(for phase: MarkdownContract.TimelinePhase, fallback: AnimationEffectKey) -> AnimationEffectKey {
        guard case let .string(raw)? = phase.metadata["effectKey"] else { return fallback }
        return AnimationEffectKey(rawValue: raw)
    }

    func sanitized(_ value: String) -> String {
        let reduced = value.map { char -> Character in
            if char.isLetter || char.isNumber || char == "." || char == "_" {
                return char
            }
            return "_"
        }
        return String(reduced)
    }
}
