import UIKit

public final class ContractBlockQuoteContainerFragment: ContainerFragment, ProgressivelyRevealable, TransitionPreferring {
    public let fragmentId: String
    public let nodeType: FragmentNodeType
    public var spacingAfter: CGFloat = 0
    public let reuseIdentifier: ReuseIdentifier
    public let childFragments: [RenderFragment]
    public let totalContentLength: Int

    public let enterTransition: (any ViewTransition)? = nil
    public let exitTransition: (any ViewTransition)? = nil

    private let config: ContractBlockQuoteContainerConfiguration

    public init(fragmentId: String, config: ContractBlockQuoteContainerConfiguration) {
        self.fragmentId = fragmentId
        self.nodeType = .blockQuote
        self.reuseIdentifier = .contractBlockQuoteContainer
        self.childFragments = config.childFragments
        self.totalContentLength = config.childFragments.reduce(0) { partial, child in
            partial + ((child as? ProgressivelyRevealable)?.totalContentLength ?? 1)
        }
        self.config = config
    }

    public func makeView() -> UIView {
        ContractBlockQuoteContainerView()
    }

    public func configure(_ view: UIView) {
        guard let containerView = view as? ContractBlockQuoteContainerView else { return }
        containerView.configure(config)
    }

    public func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? ContractBlockQuoteContainerFragment else { return false }
        guard fragmentId == rhs.fragmentId else { return false }
        guard nodeType == rhs.nodeType else { return false }
        guard spacingAfter == rhs.spacingAfter else { return false }
        guard reuseIdentifier == rhs.reuseIdentifier else { return false }
        guard totalContentLength == rhs.totalContentLength else { return false }
        guard config.depth == rhs.config.depth else { return false }
        guard config.barWidth == rhs.config.barWidth else { return false }
        guard config.barLeftMargin == rhs.config.barLeftMargin else { return false }
        guard config.barColor.isEqual(rhs.config.barColor) else { return false }
        return true
    }
}
