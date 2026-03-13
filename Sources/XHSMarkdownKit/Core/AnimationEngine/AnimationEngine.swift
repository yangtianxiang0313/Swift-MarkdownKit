import Foundation

public protocol AnimationEngine: AnyObject {
    var onAnimationComplete: (() -> Void)? { get set }
    var onLayoutChange: (() -> Void)? { get set }
    var onProgress: ((AnimationProgress) -> Void)? { get set }

    func registerEffect(_ key: AnimationEffectKey, factory: @escaping () -> StepEffect)
    func submit(_ transaction: AnimationTransaction, to container: FragmentContaining)
    func streamDidFinish(in container: FragmentContaining)
    func finishAll(in container: FragmentContaining)
}
