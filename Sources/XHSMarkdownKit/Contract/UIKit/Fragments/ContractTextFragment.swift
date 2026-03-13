import UIKit

public final class ContractTextFragment: LeafFragment, ProgressivelyRevealable, TransitionPreferring, AttributedStringProviding, MergeableFragment {
    public let fragmentId: String
    public let nodeType: FragmentNodeType
    public var spacingAfter: CGFloat = 0
    public let reuseIdentifier: ReuseIdentifier
    public let totalContentLength: Int
    public let enterTransition: (any ViewTransition)?
    public let exitTransition: (any ViewTransition)?
    public let context: FragmentContext
    public let attributedString: NSAttributedString?

    private let _makeView: () -> UIView
    private let _configure: (UIView, NSAttributedString) -> Void

    public init(
        fragmentId: String,
        nodeType: FragmentNodeType,
        reuseIdentifier: ReuseIdentifier = .contractTextView,
        context: FragmentContext = FragmentContext(),
        attributedString: NSAttributedString,
        enterTransition: (any ViewTransition)? = nil,
        exitTransition: (any ViewTransition)? = nil,
        makeView: @escaping () -> UIView,
        configure: @escaping (UIView, NSAttributedString) -> Void
    ) {
        self.fragmentId = fragmentId
        self.nodeType = nodeType
        self.reuseIdentifier = reuseIdentifier
        self.context = context
        self.attributedString = attributedString
        self.totalContentLength = attributedString.length
        self.enterTransition = enterTransition
        self.exitTransition = exitTransition
        self._makeView = makeView
        self._configure = configure
    }

    public func makeView() -> UIView {
        _makeView()
    }

    public func configure(_ view: UIView) {
        guard let attributedString else { return }
        _configure(view, attributedString)
    }

    public func canMerge(with other: RenderFragment) -> Bool {
        guard let rhs = other as? ContractTextFragment else { return false }
        guard reuseIdentifier == .contractTextView, rhs.reuseIdentifier == .contractTextView else { return false }
        guard let lhs = attributedString, let rhsAttr = rhs.attributedString else { return false }

        guard context.canMergeTextLayout(with: rhs.context) else { return false }
        return lhs.isTextLike && rhsAttr.isTextLike
    }

    public func merged(with other: RenderFragment, interFragmentSpacing: CGFloat) -> RenderFragment {
        guard let rhs = other as? ContractTextFragment,
              let lhsAttr = attributedString,
              let rhsAttr = rhs.attributedString
        else {
            return self
        }

        let merged = NSMutableAttributedString(attributedString: lhsAttr)
        merged.append(NSAttributedString.blockSeparator(
            spacing: max(0, interFragmentSpacing),
            attributesSource: lhsAttr
        ))
        merged.append(rhsAttr)

        return ContractTextFragment(
            fragmentId: fragmentId,
            nodeType: rhs.nodeType,
            reuseIdentifier: reuseIdentifier,
            context: context,
            attributedString: merged,
            enterTransition: enterTransition,
            exitTransition: exitTransition,
            makeView: _makeView,
            configure: _configure
        )
    }

    public func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? ContractTextFragment else { return false }
        guard fragmentId == rhs.fragmentId else { return false }
        guard nodeType == rhs.nodeType else { return false }
        guard spacingAfter == rhs.spacingAfter else { return false }
        guard reuseIdentifier == rhs.reuseIdentifier else { return false }
        guard totalContentLength == rhs.totalContentLength else { return false }

        switch (attributedString, rhs.attributedString) {
        case let (lhs?, rhs?):
            return lhs.isEqual(to: rhs)
        case (nil, nil):
            return true
        default:
            return false
        }
    }
}

private extension NSAttributedString {
    var isTextLike: Bool {
        guard length > 0 else { return true }

        var textLike = true
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: length), options: []) { value, _, stop in
            if value != nil {
                textLike = false
                stop.pointee = true
            }
        }
        return textLike
    }

    static func blockSeparator(spacing: CGFloat, attributesSource: NSAttributedString) -> NSAttributedString {
        let attrs = attributesSource.attributes(
            at: max(0, attributesSource.length - 1),
            effectiveRange: nil
        )
        let paragraphStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = spacing

        var separatorAttrs = attrs
        separatorAttrs[.paragraphStyle] = paragraphStyle
        return NSAttributedString(string: "\n", attributes: separatorAttrs)
    }
}

private extension FragmentContext {
    func canMergeTextLayout(with other: FragmentContext) -> Bool {
        self[IndentKey.self] == other[IndentKey.self]
    }
}
