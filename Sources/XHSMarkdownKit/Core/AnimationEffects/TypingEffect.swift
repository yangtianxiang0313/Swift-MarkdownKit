import Foundation

public final class TypingEffect: StepEffect {
    public enum EntityAppearanceMode {
        case sequential
        case simultaneous
    }

    public let charactersPerSecond: Int
    public let entityAppearanceMode: EntityAppearanceMode

    public init(
        charactersPerSecond: Int = 30,
        entityAppearanceMode: EntityAppearanceMode = .sequential
    ) {
        self.charactersPerSecond = max(1, charactersPerSecond)
        self.entityAppearanceMode = entityAppearanceMode
    }

    public func apply(step: AnimationStep, host: any SceneAnimationHost) -> AnimationEffectStatus {
        host.applySceneSnapshot(step.toScene)
        return .finished
    }
}
