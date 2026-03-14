import Foundation

public final class SegmentFadeInEffect: StepEffect {
    public init() {}

    public func apply(step: AnimationStep, host: any SceneAnimationHost) -> AnimationEffectStatus {
        host.applySceneSnapshot(step.toScene)
        return .finished
    }
}
