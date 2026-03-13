import UIKit

// MARK: - ContainerFragment for BlockQuote

public final class BlockQuoteContainerFragment: ContainerFragment, ProgressivelyRevealable, TransitionPreferring {
    public let fragmentId: String
    public let nodeType: FragmentNodeType
    public var spacingAfter: CGFloat = 0
    public let reuseIdentifier: ReuseIdentifier
    public let childFragments: [RenderFragment]
    public let totalContentLength: Int

    public let enterTransition: (any ViewTransition)? = nil
    public let exitTransition: (any ViewTransition)? = nil

    private let config: BlockQuoteContainerConfiguration

    public init(fragmentId: String, config: BlockQuoteContainerConfiguration) {
        self.fragmentId = fragmentId
        self.nodeType = .blockQuote
        self.reuseIdentifier = .blockQuoteContainer
        self.childFragments = config.childFragments
        self.totalContentLength = config.childFragments.reduce(0) { partial, child in
            partial + ((child as? ProgressivelyRevealable)?.totalContentLength ?? 1)
        }
        self.config = config
    }

    public func makeView() -> UIView {
        BlockQuoteContainerView()
    }

    public func configure(_ view: UIView) {
        guard let containerView = view as? BlockQuoteContainerView else { return }
        containerView.configure(config)
    }

    public func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? BlockQuoteContainerFragment else { return false }
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

// MARK: - Renderer

public struct DefaultBlockQuoteRenderer: NodeRenderer {
    public init() {}

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        guard node is BlockQuoteNode else { return [] }
        let childContext = context.enteringBlockQuote()
        let children = childRenderer.renderChildrenWithPath(of: node, context: childContext, pathPrefix: "bq")
        let fragmentId = context.fragmentId(nodeType: "blockQuote", index: 0)

        // 创建 Configuration
        let config = BlockQuoteContainerConfiguration(
            childFragments: children,
            // Each blockquote container should render only its own bar.
            // Nested levels are represented by nested container views.
            depth: 1,
            barColor: context.theme.blockQuote.barColor,
            barWidth: context.theme.blockQuote.barWidth,
            barLeftMargin: context.theme.blockQuote.barLeftMargin
        )

        return [BlockQuoteContainerFragment(
            fragmentId: fragmentId,
            config: config
        )]
    }
}
