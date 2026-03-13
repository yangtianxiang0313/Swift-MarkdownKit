import Foundation

public protocol ContractAnimationPlanMapping {
    func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        defaultEffectKey: AnimationEffectKey
    ) -> AnimationPlan
}

public struct DefaultContractAnimationPlanMapper: ContractAnimationPlanMapping {
    public init() {}

    public func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        defaultEffectKey: AnimationEffectKey
    ) -> AnimationPlan {
        guard !changes.isEmpty else { return .empty }

        let phases = orderedPhases(from: contractPlan.timeline)
        let tracksByID = Dictionary(uniqueKeysWithValues: contractPlan.timeline.tracks.map { ($0.id, $0) })

        var remaining = changes
        var steps: [AnimationStep] = []
        var cursor = oldFragments
        var previousStepID: AnimationStep.StepID?

        for (index, phase) in phases.enumerated() {
            let supportedKinds = changeKinds(for: phase, tracksByID: tracksByID)
            guard !supportedKinds.isEmpty else { continue }

            let phaseChanges = takeChanges(from: &remaining, matching: supportedKinds)
            guard !phaseChanges.isEmpty else { continue }

            let next = apply(phaseChanges, to: cursor)
            let stepID = "contract.\(sanitized(phase.id)).\(index)"

            steps.append(AnimationStep(
                id: stepID,
                dependencies: previousStepID.map { [$0] } ?? [],
                effectKey: effectKey(for: phase, fallback: defaultEffectKey),
                changes: phaseChanges,
                oldFragments: cursor,
                newFragments: next
            ))

            cursor = next
            previousStepID = stepID
        }

        if !remaining.isEmpty {
            let next = apply(remaining, to: cursor)
            let remainderStepID = "contract.remainder"
            steps.append(AnimationStep(
                id: remainderStepID,
                dependencies: previousStepID.map { [$0] } ?? [],
                effectKey: defaultEffectKey,
                changes: remaining,
                oldFragments: cursor,
                newFragments: next
            ))
            cursor = next
            previousStepID = remainderStepID
        }

        if steps.isEmpty {
            let next = apply(changes, to: oldFragments)
            let fallbackStep = AnimationStep(
                id: "contract.fallback",
                effectKey: defaultEffectKey,
                changes: changes,
                oldFragments: oldFragments,
                newFragments: next
            )
            steps = [fallbackStep]
            cursor = next
            previousStepID = fallbackStep.id
        }

        if cursor.map(\.fragmentId) != newFragments.map(\.fragmentId) {
            steps.append(AnimationStep(
                id: "contract.finalize",
                dependencies: previousStepID.map { [$0] } ?? [],
                effectKey: .instant,
                changes: [],
                oldFragments: cursor,
                newFragments: newFragments
            ))
        }

        return AnimationPlan(steps: steps)
    }
}

private extension DefaultContractAnimationPlanMapper {
    enum ChangeKind: String, CaseIterable {
        case insert
        case remove
        case update
        case move
    }

    func changeKinds(
        for phase: MarkdownContract.TimelinePhase,
        tracksByID: [String: MarkdownContract.TimelineTrack]
    ) -> Set<ChangeKind> {
        var result = Set<ChangeKind>(phase.trackIds.compactMap { trackID in
            guard let track = tracksByID[trackID] else { return nil }
            guard case let .string(raw)? = track.metadata["changeType"] else { return nil }
            return ChangeKind(rawValue: raw)
        })

        if !result.isEmpty {
            return result
        }

        let name = phase.name.lowercased()
        if name.contains("structure") {
            result.formUnion([ChangeKind.insert, ChangeKind.remove, ChangeKind.move])
        }
        if name.contains("content") || name.contains("update") {
            result.insert(ChangeKind.update)
        }
        if name.contains("insert") {
            result.insert(ChangeKind.insert)
        }
        if name.contains("remove") {
            result.insert(ChangeKind.remove)
        }
        if name.contains("move") {
            result.insert(ChangeKind.move)
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

    func takeChanges(from changes: inout [FragmentChange], matching kinds: Set<ChangeKind>) -> [FragmentChange] {
        guard !kinds.isEmpty else { return [] }

        var matched: [FragmentChange] = []
        var remained: [FragmentChange] = []
        matched.reserveCapacity(changes.count)
        remained.reserveCapacity(changes.count)

        for change in changes {
            if kinds.contains(kind(of: change)) {
                matched.append(change)
            } else {
                remained.append(change)
            }
        }

        changes = remained
        return matched
    }

    func kind(of change: FragmentChange) -> ChangeKind {
        switch change {
        case .insert:
            return .insert
        case .remove:
            return .remove
        case .update:
            return .update
        case .move:
            return .move
        }
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

    func apply(_ changes: [FragmentChange], to fragments: [RenderFragment]) -> [RenderFragment] {
        changes.reduce(fragments) { current, change in
            apply(change, to: current)
        }
    }

    func apply(_ change: FragmentChange, to fragments: [RenderFragment]) -> [RenderFragment] {
        var result = fragments

        switch change {
        case .insert(let fragment, let index):
            let safeIndex = max(0, min(index, result.count))
            result.insert(fragment, at: safeIndex)

        case .remove(let fragmentID, _):
            if let index = result.firstIndex(where: { $0.fragmentId == fragmentID }) {
                result.remove(at: index)
            }

        case .update(_, let newFragment, _):
            if let index = result.firstIndex(where: { $0.fragmentId == newFragment.fragmentId }) {
                result[index] = newFragment
            }

        case .move(let fragmentID, _, let to):
            guard let from = result.firstIndex(where: { $0.fragmentId == fragmentID }) else { return result }
            let fragment = result.remove(at: from)
            let safeTo = max(0, min(to, result.count))
            result.insert(fragment, at: safeTo)
        }

        return result
    }
}
