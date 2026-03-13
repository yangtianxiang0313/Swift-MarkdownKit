import Foundation

public protocol AnimationPlanProvider {
    func makePlan(
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        policy: ConflictPolicy
    ) -> AnimationPlan
}
