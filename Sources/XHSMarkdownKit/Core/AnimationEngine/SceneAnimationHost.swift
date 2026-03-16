import Foundation

public protocol SceneAnimationHost: AnyObject {
    var currentSceneSnapshot: RenderScene { get }
    func applySceneSnapshot(_ scene: RenderScene)
}
