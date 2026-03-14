import Foundation

public struct AnimationStep {
    public typealias StepID = String

    public let id: StepID
    public let dependencies: Set<StepID>
    public let effectKey: AnimationEffectKey
    public let entityIDs: [String]
    public let fromScene: RenderScene
    public let toScene: RenderScene

    public init(
        id: StepID,
        dependencies: Set<StepID> = [],
        effectKey: AnimationEffectKey,
        entityIDs: [String],
        fromScene: RenderScene,
        toScene: RenderScene
    ) {
        self.id = id
        self.dependencies = dependencies
        self.effectKey = effectKey
        self.entityIDs = entityIDs
        self.fromScene = fromScene
        self.toScene = toScene
    }
}
