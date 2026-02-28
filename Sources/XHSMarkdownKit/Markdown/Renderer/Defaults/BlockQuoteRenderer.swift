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

    private let depth: Int
    private let theme: MarkdownTheme

    public init(fragmentId: String, childFragments: [RenderFragment], depth: Int, theme: MarkdownTheme) {
        self.fragmentId = fragmentId
        self.nodeType = .blockQuote
        self.reuseIdentifier = .blockQuoteContainer
        self.childFragments = childFragments
        self.depth = depth
        self.theme = theme
    }

    public func makeView() -> UIView {
        BlockQuoteContainerView()
    }

    public func configure(_ view: UIView) {
        guard let containerView = view as? BlockQuoteContainerView else { return }
        containerView.configure(
            childFragments: childFragments,
            depth: depth,
            theme: theme.blockQuote
        )
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

        return [BlockQuoteContainerFragment(
            fragmentId: fragmentId,
            childFragments: children,
            depth: context.blockQuoteDepth + 1,
            theme: context.theme
        )]
    }
}
