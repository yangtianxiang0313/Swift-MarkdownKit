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
    public let content: any FragmentContent
    private let maxWidthHint: CGFloat

    // MARK: - Init

    public init<Content: FragmentContent>(
        fragmentId: String,
        nodeType: FragmentNodeType,
        reuseIdentifier: ReuseIdentifier,
        context: FragmentContext = FragmentContext(),
        content: Content,
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
        self.maxWidthHint = context[MaxWidthKey.self]
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
        content.attributedStringValue
    }
}

// MARK: - RenderFragment Content Equality

extension ViewFragment {
    public func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? ViewFragment else { return false }
        guard fragmentId == rhs.fragmentId else { return false }
        guard nodeType == rhs.nodeType else { return false }
        guard spacingAfter == rhs.spacingAfter else { return false }
        guard reuseIdentifier.rawValue == rhs.reuseIdentifier.rawValue else { return false }
        guard maxWidthHint == rhs.maxWidthHint else { return false }
        guard totalContentLength == rhs.totalContentLength else { return false }
        return content.isEqual(to: rhs.content)
    }
}
