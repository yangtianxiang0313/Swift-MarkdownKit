import UIKit

public struct DefaultListItemRenderer: NodeRenderer {
    public init() {}

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        guard let listItem = node as? ListItemNode else { return [] }

        let marker = makeMarker(for: listItem, context: context)

        var results: [RenderFragment] = []
        for (index, child) in node.children.enumerated() {
            var childContext = context.appendingPath("li_\(index)")
            if index == 0, let marker = marker {
                childContext = childContext.setting(ListMarkerKey.self, to: marker)
            }
            let fragments = childRenderer.render(child, context: childContext)
            results.append(contentsOf: fragments)
        }
        return results
    }

    private func makeMarker(for listItem: ListItemNode, context: RenderContext) -> NSAttributedString? {
        let theme = context.theme
        let font = theme.body.font
        let color = theme.body.color

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        if let checked = listItem.checkbox {
            let symbol = checked ? "☑ " : "☐ "
            return NSAttributedString(string: symbol, attributes: attrs)
        }

        let isOrdered = context[IsOrderedListKey.self]
        if isOrdered {
            let index = context[ListItemIndexKey.self] ?? 1
            return NSAttributedString(string: "\(index). ", attributes: attrs)
        } else {
            let depth = context.listDepth
            let bullet: String
            switch (depth - 1) % 3 {
            case 0: bullet = "•"
            case 1: bullet = "◦"
            default: bullet = "▪"
            }
            return NSAttributedString(string: "\(bullet) ", attributes: attrs)
        }
    }
}
