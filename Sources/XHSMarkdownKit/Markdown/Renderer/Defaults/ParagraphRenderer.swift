import UIKit

public struct DefaultParagraphRenderer: LeafNodeRenderer {
    public init() {}

    public func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard let paragraph = node as? ParagraphNode else { return [] }
        let rendered = InlineRenderer.render(paragraph.inlineChildren, context: context)
        guard rendered.length > 0 else { return [] }

        let attrString: NSAttributedString
        if let marker = context[ListMarkerKey.self] {
            let combined = NSMutableAttributedString(attributedString: marker)
            combined.append(rendered)
            attrString = combined
        } else {
            attrString = rendered
        }

        let strategy = context[TextViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()
        let theme = context.theme
        let fragmentId = context.fragmentId(nodeType: "paragraph", index: 0)

        return [ViewFragment(
            fragmentId: fragmentId,
            nodeType: .paragraph,
            reuseIdentifier: .textView,
            context: fragmentContext,
            content: attrString,
            totalContentLength: attrString.length,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, attributedString: attrString, context: fragmentContext, theme: theme)
            }
        )]
    }
}
