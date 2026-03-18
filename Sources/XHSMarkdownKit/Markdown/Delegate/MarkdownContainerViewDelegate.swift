import UIKit

public protocol MarkdownContainerViewDelegate: AnyObject {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat)
    func containerViewDidCompleteAnimation(_ view: MarkdownContainerView)
    func containerView(_ view: MarkdownContainerView, didUpdateAnimationProgress progress: AnimationProgress)
    func containerView(_ view: MarkdownContainerView, didFailRender error: Error, forDocumentID documentID: String)
}

public extension MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {}
    func containerViewDidCompleteAnimation(_ view: MarkdownContainerView) {}
    func containerView(_ view: MarkdownContainerView, didUpdateAnimationProgress progress: AnimationProgress) {}
    func containerView(_ view: MarkdownContainerView, didFailRender error: Error, forDocumentID documentID: String) {}
}
