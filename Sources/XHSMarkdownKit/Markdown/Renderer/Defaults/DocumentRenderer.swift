import Foundation

public struct DefaultDocumentRenderer: NodeRenderer {
    public init() {}

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        childRenderer.renderChildrenWithPath(of: node, context: context, pathPrefix: "doc")
    }
}
