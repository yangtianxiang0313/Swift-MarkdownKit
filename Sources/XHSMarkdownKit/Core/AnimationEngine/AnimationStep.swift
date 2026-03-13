import Foundation

public struct AnimationStep {
    public typealias StepID = String

    public let id: StepID
    public let dependencies: Set<StepID>
    public let effectKey: AnimationEffectKey
    public let changes: [FragmentChange]
    public let oldFragments: [RenderFragment]
    public let newFragments: [RenderFragment]

    public init(
        id: StepID,
        dependencies: Set<StepID> = [],
        effectKey: AnimationEffectKey,
        changes: [FragmentChange],
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment]
    ) {
        self.id = id
        self.dependencies = dependencies
        self.effectKey = effectKey
        self.changes = changes
        self.oldFragments = oldFragments
        self.newFragments = newFragments
    }
}
