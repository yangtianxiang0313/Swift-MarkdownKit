import Foundation

/// Reserved for future transition-specific orchestration.
public final class TransitionEffect: StepEffect {
    private let fallback = InstantEffect()

    public init() {}

    public func prepare(step: AnimationStep, context: AnimationExecutionContext) {
        fallback.prepare(step: step, context: context)
    }

    public func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus {
        fallback.advance(deltaTime: deltaTime, context: context)
    }
}
