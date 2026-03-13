import UIKit

public final class ContractViewFragment: LeafFragment, ProgressivelyRevealable, TransitionPreferring {

    public let fragmentId: String
    public let nodeType: FragmentNodeType
    public var spacingAfter: CGFloat = 0

    public let reuseIdentifier: ReuseIdentifier

    private let _makeView: () -> UIView
    private let _configure: (UIView) -> Void

    public func makeView() -> UIView { _makeView() }
    public func configure(_ view: UIView) { _configure(view) }

    public let totalContentLength: Int

    public let enterTransition: (any ViewTransition)?
    public let exitTransition: (any ViewTransition)?

    public let context: FragmentContext
    public let content: any FragmentContent
    private let maxWidthHint: CGFloat

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

extension ContractViewFragment: AttributedStringProviding {
    public var attributedString: NSAttributedString? {
        content.attributedStringValue
    }
}

extension ContractViewFragment {
    public func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? ContractViewFragment else { return false }
        guard fragmentId == rhs.fragmentId else { return false }
        guard nodeType == rhs.nodeType else { return false }
        guard spacingAfter == rhs.spacingAfter else { return false }
        guard reuseIdentifier.rawValue == rhs.reuseIdentifier.rawValue else { return false }
        guard maxWidthHint == rhs.maxWidthHint else { return false }
        guard totalContentLength == rhs.totalContentLength else { return false }
        return content.isEqual(to: rhs.content)
    }
}
