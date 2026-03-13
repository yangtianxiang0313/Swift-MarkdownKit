import UIKit

public protocol MarkdownContainerViewDelegate: AnyObject {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat)
    func containerViewDidCompleteAnimation(_ view: MarkdownContainerView)
    func containerView(_ view: MarkdownContainerView, didUpdateAnimationProgress progress: AnimationProgress)
    func containerView(_ view: MarkdownContainerView, didUpdateRevealAnchor anchorY: CGFloat)
    func containerView(_ view: MarkdownContainerView, didReceiveEvent event: FragmentEvent)
}

public extension MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {}
    func containerViewDidCompleteAnimation(_ view: MarkdownContainerView) {}
    func containerView(_ view: MarkdownContainerView, didUpdateAnimationProgress progress: AnimationProgress) {}
    func containerView(_ view: MarkdownContainerView, didUpdateRevealAnchor anchorY: CGFloat) {}
    func containerView(_ view: MarkdownContainerView, didReceiveEvent event: FragmentEvent) {}
}
