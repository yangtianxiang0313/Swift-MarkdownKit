import Foundation

public final class InstantEffect: StepEffect {
    private var isCompleted = false

    public init() {}

    public func prepare(step: AnimationStep, context: AnimationExecutionContext) {
        guard context.container != nil else {
            isCompleted = true
            return
        }

        context.notifyLayoutChange()
        isCompleted = true
    }

    public func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus {
        isCompleted ? .finished : .running
    }
}
