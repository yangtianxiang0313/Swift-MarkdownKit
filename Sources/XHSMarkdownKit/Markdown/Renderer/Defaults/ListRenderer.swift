import UIKit

public struct DefaultOrderedListRenderer: NodeRenderer {
    public init() {}

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        guard node is OrderedListNode else { return [] }
        let listContext = context.enteringList()
            .setting(IsOrderedListKey.self, to: true)

        return node.children.enumerated().flatMap { index, child in
            let itemContext = listContext
                .setting(ListItemIndexKey.self, to: index + 1)
                .appendingPath("ol_\(index)")
            return childRenderer.render(child, context: itemContext)
        }
    }
}

public struct DefaultUnorderedListRenderer: NodeRenderer {
    public init() {}

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        guard node is UnorderedListNode else { return [] }
        let listContext = context.enteringList()
            .setting(IsOrderedListKey.self, to: false)

        return node.children.enumerated().flatMap { index, child in
            let itemContext = listContext
                .setting(ListItemIndexKey.self, to: index + 1)
                .appendingPath("ul_\(index)")
            return childRenderer.render(child, context: itemContext)
        }
    }
}
