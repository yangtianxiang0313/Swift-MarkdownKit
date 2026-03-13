import Foundation

public struct DefaultAnimationPlanProvider: AnimationPlanProvider {

    public init() {}

    public func makePlan(
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        policy: ConflictPolicy
    ) -> AnimationPlan {
        guard !changes.isEmpty else { return .empty }

        switch policy.schedulingMode {
        case .groupedByPhase:
            return makeGroupedPlan(
                oldFragments: oldFragments,
                newFragments: newFragments,
                changes: changes,
                effectKey: policy.defaultEffectKey
            )

        case .serialByChange:
            return makeSerialPlan(
                oldFragments: oldFragments,
                newFragments: newFragments,
                changes: sortedChanges(changes),
                effectKey: policy.defaultEffectKey
            )

        case .parallelByChange:
            return makeParallelPlan(
                oldFragments: oldFragments,
                newFragments: newFragments,
                changes: sortedChanges(changes),
                effectKey: policy.defaultEffectKey
            )
        }
    }

    // MARK: - Grouped Plan

    private func makeGroupedPlan(
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        effectKey: AnimationEffectKey
    ) -> AnimationPlan {
        let removes = changes.filter { if case .remove = $0 { return true } else { return false } }
        let updates = changes.filter { if case .update = $0 { return true } else { return false } }
        let moves = changes.filter { if case .move = $0 { return true } else { return false } }
        let inserts = changes.filter { if case .insert = $0 { return true } else { return false } }

        let newMap = Dictionary(uniqueKeysWithValues: newFragments.map { ($0.fragmentId, $0) })

        var steps: [AnimationStep] = []
        var dependencies: Set<AnimationStep.StepID> = []
        var cursor = oldFragments

        if !removes.isEmpty {
            let next = apply(removes, to: cursor)
            steps.append(AnimationStep(
                id: "phase.remove",
                dependencies: dependencies,
                effectKey: effectKey,
                changes: removes,
                oldFragments: cursor,
                newFragments: next
            ))
            dependencies = ["phase.remove"]
            cursor = next
        }

        if !updates.isEmpty {
            let next = cursor.map { fragment in
                if let replacement = newMap[fragment.fragmentId] {
                    return replacement
                }
                return fragment
            }
            steps.append(AnimationStep(
                id: "phase.update",
                dependencies: dependencies,
                effectKey: effectKey,
                changes: updates,
                oldFragments: cursor,
                newFragments: next
            ))
            dependencies = ["phase.update"]
            cursor = next
        }

        if !moves.isEmpty {
            let next = apply(moves, to: cursor)
            steps.append(AnimationStep(
                id: "phase.move",
                dependencies: dependencies,
                effectKey: effectKey,
                changes: moves,
                oldFragments: cursor,
                newFragments: next
            ))
            dependencies = ["phase.move"]
            cursor = next
        }

        if !inserts.isEmpty {
            let next = apply(inserts, to: cursor)
            steps.append(AnimationStep(
                id: "phase.insert",
                dependencies: dependencies,
                effectKey: effectKey,
                changes: inserts,
                oldFragments: cursor,
                newFragments: next
            ))
            cursor = next
        }

        if steps.isEmpty {
            let fallback = AnimationStep(
                id: "phase.apply",
                dependencies: [],
                effectKey: effectKey,
                changes: changes,
                oldFragments: oldFragments,
                newFragments: newFragments
            )
            return AnimationPlan(steps: [fallback])
        }

        if cursor.map(\.fragmentId) != newFragments.map(\.fragmentId) {
            let fix = AnimationStep(
                id: "phase.finalize",
                dependencies: Set([steps.last!.id]),
                effectKey: .instant,
                changes: [],
                oldFragments: cursor,
                newFragments: newFragments
            )
            steps.append(fix)
        }

        return AnimationPlan(steps: steps)
    }

    // MARK: - Serial Plan

    private func makeSerialPlan(
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        effectKey: AnimationEffectKey
    ) -> AnimationPlan {
        var steps: [AnimationStep] = []
        var cursor = oldFragments
        var previousId: AnimationStep.StepID?

        for (index, change) in changes.enumerated() {
            let stepId = "serial.\(index)"
            let next = apply(change, to: cursor)
            let dependencies = previousId.map { Set([$0]) } ?? []

            steps.append(AnimationStep(
                id: stepId,
                dependencies: dependencies,
                effectKey: effectKey,
                changes: [change],
                oldFragments: cursor,
                newFragments: next
            ))

            cursor = next
            previousId = stepId
        }

        return withFinalizeStepIfNeeded(
            steps: steps,
            cursor: cursor,
            target: newFragments
        )
    }

    // MARK: - Parallel Plan

    private func makeParallelPlan(
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        effectKey: AnimationEffectKey
    ) -> AnimationPlan {
        if !supportsConcurrentExecution(effectKey: effectKey) {
            return makeSerialPlan(
                oldFragments: oldFragments,
                newFragments: newFragments,
                changes: changes,
                effectKey: effectKey
            )
        }

        var steps: [AnimationStep] = []
        var cursor = oldFragments
        var prior: [(id: AnimationStep.StepID, change: FragmentChange)] = []

        for (index, change) in changes.enumerated() {
            let stepId = "parallel.\(index)"
            let dependencies = Set(prior.compactMap { entry in
                conflicts(entry.change, change) ? entry.id : nil
            })
            let next = apply(change, to: cursor)
            steps.append(AnimationStep(
                id: stepId,
                dependencies: dependencies,
                effectKey: effectKey,
                changes: [change],
                oldFragments: cursor,
                newFragments: next
            ))
            cursor = next
            prior.append((id: stepId, change: change))
        }

        return withFinalizeStepIfNeeded(
            steps: steps,
            cursor: cursor,
            target: newFragments
        )
    }

    // MARK: - Helpers

    private func sortedChanges(_ changes: [FragmentChange]) -> [FragmentChange] {
        changes.sorted { lhs, rhs in
            let lhsRank = rank(of: lhs)
            let rhsRank = rank(of: rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            let lhsPos = position(of: lhs)
            let rhsPos = position(of: rhs)
            if lhsPos != rhsPos {
                return lhsPos < rhsPos
            }
            return fragmentIdentifier(of: lhs) < fragmentIdentifier(of: rhs)
        }
    }

    private func rank(of change: FragmentChange) -> Int {
        switch change {
        case .remove: return 0
        case .update: return 1
        case .move: return 2
        case .insert: return 3
        }
    }

    private func position(of change: FragmentChange) -> Int {
        switch change {
        case .insert(_, let at):
            return at
        case .remove(_, let at):
            return at
        case .update:
            return Int.max / 2
        case .move(_, _, let to):
            return to
        }
    }

    private func fragmentIdentifier(of change: FragmentChange) -> String {
        switch change {
        case .insert(let fragment, _):
            return fragment.fragmentId
        case .remove(let fragmentId, _):
            return fragmentId
        case .update(_, let newFragment, _):
            return newFragment.fragmentId
        case .move(let fragmentId, _, _):
            return fragmentId
        }
    }

    private func apply(_ changes: [FragmentChange], to fragments: [RenderFragment]) -> [RenderFragment] {
        changes.reduce(fragments) { current, change in
            apply(change, to: current)
        }
    }

    private func apply(_ change: FragmentChange, to fragments: [RenderFragment]) -> [RenderFragment] {
        var result = fragments

        switch change {
        case .insert(let fragment, let index):
            let safeIndex = max(0, min(index, result.count))
            result.insert(fragment, at: safeIndex)

        case .remove(let fragmentId, _):
            if let idx = result.firstIndex(where: { $0.fragmentId == fragmentId }) {
                result.remove(at: idx)
            }

        case .update(_, let newFragment, _):
            if let idx = result.firstIndex(where: { $0.fragmentId == newFragment.fragmentId }) {
                result[idx] = newFragment
            }

        case .move(let fragmentId, _, let to):
            guard let fromIdx = result.firstIndex(where: { $0.fragmentId == fragmentId }) else { return result }
            let fragment = result.remove(at: fromIdx)
            let safeTo = max(0, min(to, result.count))
            result.insert(fragment, at: safeTo)
        }

        return result
    }

    private func withFinalizeStepIfNeeded(
        steps: [AnimationStep],
        cursor: [RenderFragment],
        target: [RenderFragment]
    ) -> AnimationPlan {
        guard !steps.isEmpty else { return .empty }
        guard cursor.map(\.fragmentId) != target.map(\.fragmentId) else {
            return AnimationPlan(steps: steps)
        }

        var finalized = steps
        finalized.append(AnimationStep(
            id: "finalize",
            dependencies: Set([steps.last!.id]),
            effectKey: .instant,
            changes: [],
            oldFragments: cursor,
            newFragments: target
        ))
        return AnimationPlan(steps: finalized)
    }

    private func supportsConcurrentExecution(effectKey: AnimationEffectKey) -> Bool {
        effectKey == .instant
    }

    private func conflicts(_ lhs: FragmentChange, _ rhs: FragmentChange) -> Bool {
        let lhsIsStructural = isStructural(lhs)
        let rhsIsStructural = isStructural(rhs)
        if lhsIsStructural || rhsIsStructural {
            return true
        }

        return fragmentIdentifier(of: lhs) == fragmentIdentifier(of: rhs)
    }

    private func isStructural(_ change: FragmentChange) -> Bool {
        switch change {
        case .insert, .remove, .move:
            return true
        case .update:
            return false
        }
    }
}
