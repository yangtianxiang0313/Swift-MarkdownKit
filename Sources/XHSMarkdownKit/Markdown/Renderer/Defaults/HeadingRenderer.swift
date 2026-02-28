import UIKit

public struct DefaultHeadingRenderer: LeafNodeRenderer {
    public init() {}

    public func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard let heading = node as? HeadingNode else { return [] }
        let level = heading.level

        let theme = context.theme
        let headingFont = theme.heading.font(for: level)
        let headingColor = theme.heading.color(for: level)
        let headingLineHeight = theme.heading.lineHeight(for: level)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = headingLineHeight
        paragraphStyle.maximumLineHeight = headingLineHeight

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: headingColor,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: (headingLineHeight - headingFont.lineHeight) / 4
        ]

        let attrString = NSMutableAttributedString()
        for child in heading.inlineChildren {
            if let text = child as? TextNode {
                attrString.append(NSAttributedString(string: text.text, attributes: baseAttrs))
            } else {
                let inline = InlineRenderer.render([child], context: context)
                attrString.append(inline)
            }
        }

        if attrString.length > 0 {
            attrString.addAttributes(baseAttrs, range: NSRange(location: 0, length: attrString.length))
        }

        guard attrString.length > 0 else { return [] }

        let strategy = context[TextViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()
        let fragmentId = context.fragmentId(nodeType: "heading", index: level)

        return [ViewFragment(
            fragmentId: fragmentId,
            nodeType: .heading(level),
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
