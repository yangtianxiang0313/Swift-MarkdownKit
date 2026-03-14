import Foundation

public enum AnimationEffectStatus {
    case running
    case finished
}

public protocol StepEffect: AnyObject {
    func apply(step: AnimationStep, host: any SceneAnimationHost) -> AnimationEffectStatus
    func streamDidFinish(host: any SceneAnimationHost)
}

public extension StepEffect {
    func streamDidFinish(host: any SceneAnimationHost) {}
}
