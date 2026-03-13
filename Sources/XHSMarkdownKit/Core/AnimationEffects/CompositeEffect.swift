import Foundation

public final class CompositeEffect: StepEffect {
    private let effects: [StepEffect]

    public init(effects: [StepEffect]) {
        self.effects = effects
    }

    public func prepare(step: AnimationStep, context: AnimationExecutionContext) {
        effects.forEach { $0.prepare(step: step, context: context) }
    }

    public func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus {
        var hasRunning = false
        for effect in effects {
            if effect.advance(deltaTime: deltaTime, context: context) == .running {
                hasRunning = true
            }
        }
        return hasRunning ? .running : .finished
    }

    public func streamDidFinish(context: AnimationExecutionContext) {
        effects.forEach { $0.streamDidFinish(context: context) }
    }

    public func finish(context: AnimationExecutionContext) {
        effects.forEach { $0.finish(context: context) }
    }

    public func cancel(context: AnimationExecutionContext) {
        effects.forEach { $0.cancel(context: context) }
    }
}
