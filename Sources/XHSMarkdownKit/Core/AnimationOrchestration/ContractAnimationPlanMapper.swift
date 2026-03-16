import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public protocol ContractAnimationPlanMapping {
    func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        delta: SceneDelta,
        defaultEffectKey: AnimationEffectKey
    ) -> RenderExecutionPlan
}

public struct DefaultContractAnimationPlanMapper: ContractAnimationPlanMapping {
    public init() {}

    public func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        delta: SceneDelta,
        defaultEffectKey: AnimationEffectKey
    ) -> RenderExecutionPlan {
        guard !delta.isEmpty else { return .empty }

        let phases = orderedPhases(from: contractPlan.timeline)
        let tracksByID = Dictionary(uniqueKeysWithValues: contractPlan.timeline.tracks.map { ($0.id, $0) })

        var remainingStructural = delta.structuralChanges
        var remainingContent = delta.contentChanges
        var stages: [RenderExecutionPlan.Stage] = []

        for (index, phase) in phases.enumerated() {
            let supportedKinds = changeKinds(for: phase, tracksByID: tracksByID)
            guard !supportedKinds.isEmpty else { continue }

            let phaseStructural = takeStructuralChanges(from: &remainingStructural, matching: supportedKinds)
            let phaseContent = takeContentChanges(from: &remainingContent, matching: supportedKinds)
            guard !phaseStructural.isEmpty || !phaseContent.isEmpty else { continue }

            stages.append(RenderExecutionPlan.Stage(
                id: "contract.\(sanitized(phase.id)).\(index)",
                phase: phaseType(for: phase, kinds: supportedKinds, hasContent: !phaseContent.isEmpty),
                effectKey: effectKey(for: phase, fallback: defaultEffectKey),
                structuralChanges: phaseStructural,
                contentChanges: phaseContent
            ))
        }

        if !remainingStructural.isEmpty || !remainingContent.isEmpty {
            stages.append(RenderExecutionPlan.Stage(
                id: "contract.remainder",
                phase: !remainingContent.isEmpty ? .content : .structure,
                effectKey: defaultEffectKey,
                structuralChanges: remainingStructural,
                contentChanges: remainingContent
            ))
        }

        if stages.isEmpty {
            return RenderExecutionPlan(stages: [
                RenderExecutionPlan.Stage(
                id: "contract.fallback",
                phase: !delta.contentChanges.isEmpty ? .content : .structure,
                effectKey: defaultEffectKey,
                structuralChanges: delta.structuralChanges,
                contentChanges: delta.contentChanges
                )
            ])
        }

        return RenderExecutionPlan(stages: stages)
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

    func phaseType(
        for phase: MarkdownContract.TimelinePhase,
        kinds: Set<SceneChangeKind>,
        hasContent: Bool
    ) -> AnimationPhase {
        let lowerName = phase.name.lowercased()
        if lowerName.contains("content") || lowerName.contains("update") {
            return .content
        }
        if lowerName.contains("structure") {
            return .structure
        }
        if kinds.contains(.update) || hasContent {
            return .content
        }
        return .structure
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

    func takeStructuralChanges(
        from changes: inout [StructuralSceneChange],
        matching kinds: Set<SceneChangeKind>
    ) -> [StructuralSceneChange] {
        guard !kinds.isEmpty else { return [] }

        var matched: [StructuralSceneChange] = []
        var remained: [StructuralSceneChange] = []

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

    func takeContentChanges(
        from changes: inout [ContentSceneChange],
        matching kinds: Set<SceneChangeKind>
    ) -> [ContentSceneChange] {
        guard !kinds.isEmpty else { return [] }

        var matched: [ContentSceneChange] = []
        var remained: [ContentSceneChange] = []

        for change in changes {
            let kind: SceneChangeKind = change.inserted ? .insert : .update
            if kinds.contains(kind) {
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
