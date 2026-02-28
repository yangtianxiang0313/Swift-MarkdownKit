import UIKit

public final class ViewFragment: LeafFragment, ProgressivelyRevealable, TransitionPreferring {

    // MARK: - RenderFragment

    public let fragmentId: String
    public let nodeType: FragmentNodeType
    public var spacingAfter: CGFloat = 0

    // MARK: - FragmentViewFactory

    public let reuseIdentifier: ReuseIdentifier

    private let _makeView: () -> UIView
    private let _configure: (UIView) -> Void

    public func makeView() -> UIView { _makeView() }
    public func configure(_ view: UIView) { _configure(view) }

    // MARK: - ProgressivelyRevealable

    public let totalContentLength: Int

    // MARK: - TransitionPreferring

    public let enterTransition: (any ViewTransition)?
    public let exitTransition: (any ViewTransition)?

    // MARK: - Content

    public let context: FragmentContext
    public let content: Any

    // MARK: - Init

    public init(
        fragmentId: String,
        nodeType: FragmentNodeType,
        reuseIdentifier: ReuseIdentifier,
        context: FragmentContext = FragmentContext(),
        content: Any,
        totalContentLength: Int = 1,
        enterTransition: (any ViewTransition)? = nil,
        exitTransition: (any ViewTransition)? = nil,
        makeView: @escaping () -> UIView,
        configure: @escaping (UIView) -> Void
    ) {
        self.fragmentId = fragmentId
        self.nodeType = nodeType
        self.reuseIdentifier = reuseIdentifier
        self.context = context
        self.content = content
        self.totalContentLength = totalContentLength
        self.enterTransition = enterTransition
        self.exitTransition = exitTransition
        self._makeView = makeView
        self._configure = configure
    }
}

// MARK: - AttributedStringProviding (opt-in, content 为 NSAttributedString 时有效)

extension ViewFragment: AttributedStringProviding {
    public var attributedString: NSAttributedString? {
        content as? NSAttributedString
    }
}
