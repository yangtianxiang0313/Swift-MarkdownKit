import Foundation

public protocol AnimationDriver: AnyObject {
    func apply(changes: [FragmentChange], fragments: [RenderFragment], to container: FragmentContaining)

    /// 数据流结束（不再有新 fragment），动画继续自然播放直到完成
    func streamDidFinish()

    /// 强制跳过所有剩余动画，立即展示全部内容
    func finishAll()

    /// 动画自然播放完成时的回调
    var onAnimationComplete: (() -> Void)? { get set }

    /// 动画过程中布局发生变化时的回调（view 创建、内容 reveal 导致高度变化）
    var onLayoutChange: (() -> Void)? { get set }
}
