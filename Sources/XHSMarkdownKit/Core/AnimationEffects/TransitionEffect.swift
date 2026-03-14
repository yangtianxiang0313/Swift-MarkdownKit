import Foundation

public final class TransitionEffect: StepEffect {
    private let fallback = InstantEffect()

    public init() {}

    public func apply(step: AnimationStep, host: any SceneAnimationHost) -> AnimationEffectStatus {
        fallback.apply(step: step, host: host)
    }
}
