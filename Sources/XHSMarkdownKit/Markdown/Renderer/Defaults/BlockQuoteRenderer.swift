import UIKit

// MARK: - ContainerFragment for BlockQuote

public final class BlockQuoteContainerFragment: ContainerFragment, TransitionPreferring {
    public let fragmentId: String
    public let nodeType: FragmentNodeType
    public var spacingAfter: CGFloat = 0
    public let reuseIdentifier: ReuseIdentifier
    public let childFragments: [RenderFragment]

    public let enterTransition: (any ViewTransition)? = nil
    public let exitTransition: (any ViewTransition)? = nil

    private let config: BlockQuoteContainerConfiguration

    public init(fragmentId: String, config: BlockQuoteContainerConfiguration) {
        self.fragmentId = fragmentId
        self.nodeType = .blockQuote
        self.reuseIdentifier = .blockQuoteContainer
        self.childFragments = config.childFragments
        self.config = config
    }

    public func makeView() -> UIView {
        BlockQuoteContainerView()
    }

    public func configure(_ view: UIView) {
        guard let containerView = view as? BlockQuoteContainerView else { return }
        containerView.configure(config)
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
            depth: context.blockQuoteDepth + 1,
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
