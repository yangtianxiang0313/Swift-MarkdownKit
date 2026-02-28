import UIKit

public struct DefaultImageRenderer: LeafNodeRenderer {
    public init() {}

    public func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard let image = node as? ImageNode else { return [] }

        let content = ImageContent(source: image.source, title: image.title, altText: image.altText)
        let strategy = context[ImageViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()
        let theme = context.theme
        let fragmentId = context.fragmentId(nodeType: "image", index: 0)

        return [ViewFragment(
            fragmentId: fragmentId,
            nodeType: .image,
            reuseIdentifier: .markdownImageView,
            context: fragmentContext,
            content: content,
            totalContentLength: 1,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, content: content, context: fragmentContext, theme: theme)
            }
        )]
    }
}
