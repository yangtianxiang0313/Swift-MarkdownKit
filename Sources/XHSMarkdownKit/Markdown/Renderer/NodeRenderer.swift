import Foundation

// MARK: - NodeRenderer

public protocol NodeRenderer {
    func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment]
}

// MARK: - LeafNodeRenderer

public protocol LeafNodeRenderer: NodeRenderer {
    func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment]
}

extension LeafNodeRenderer {
    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        renderLeaf(node: node, context: context)
    }
}

// MARK: - ChildRenderer

public struct ChildRenderer {
    private let renderFunction: (MarkdownNode, RenderContext) -> [RenderFragment]

    public init(render: @escaping (MarkdownNode, RenderContext) -> [RenderFragment]) {
        self.renderFunction = render
    }

    public func render(_ node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        renderFunction(node, context)
    }

    public func renderChildren(of node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        node.children.flatMap { render($0, context: context) }
    }

    public func renderChildrenWithPath(of node: MarkdownNode, context: RenderContext, pathPrefix: String) -> [RenderFragment] {
        node.children.enumerated().flatMap { index, child in
            let childContext = context.appendingPath("\(pathPrefix)_\(index)")
            return render(child, context: childContext)
        }
    }
}

// MARK: - ClosureRenderer

public struct ClosureRenderer: NodeRenderer {
    private let closure: (MarkdownNode, RenderContext, ChildRenderer) -> [RenderFragment]

    public init(render: @escaping (MarkdownNode, RenderContext, ChildRenderer) -> [RenderFragment]) {
        self.closure = render
    }

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        closure(node, context, childRenderer)
    }
}

// MARK: - FallbackRenderer

public struct FallbackRenderer: NodeRenderer {
    public init() {}

    public func render(node: MarkdownNode, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        childRenderer.renderChildren(of: node, context: context)
    }
}
