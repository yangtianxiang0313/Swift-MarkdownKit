import Foundation

public protocol SceneAnimationHost: AnyObject {
    var currentSceneSnapshot: RenderScene { get }
    func applySceneSnapshot(_ scene: RenderScene)
}

public protocol AnimationEngine: AnyObject {
    var onAnimationComplete: (() -> Void)? { get set }
    var onLayoutChange: (() -> Void)? { get set }
    var onProgress: ((AnimationProgress) -> Void)? { get set }

    func registerEffect(_ key: AnimationEffectKey, factory: @escaping () -> StepEffect)
    func submit(_ transaction: AnimationTransaction, to host: any SceneAnimationHost)
    func streamDidFinish(in host: any SceneAnimationHost)
    func finishAll(in host: any SceneAnimationHost)
}
