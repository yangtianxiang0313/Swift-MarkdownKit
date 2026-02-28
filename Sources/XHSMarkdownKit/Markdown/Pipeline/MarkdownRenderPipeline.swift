import UIKit

public struct MarkdownRenderPipeline {

    public let parser: MarkdownParser
    public let rendererRegistry: RendererRegistry
    public let spacingResolver: BlockSpacingResolving
    public var rewriterPipeline: RewriterPipeline?

    public init(
        parser: MarkdownParser = XYMarkdownParser(),
        rendererRegistry: RendererRegistry = .makeDefault(),
        spacingResolver: BlockSpacingResolving = DefaultBlockSpacingResolver(),
        rewriterPipeline: RewriterPipeline? = nil
    ) {
        self.parser = parser
        self.rendererRegistry = rendererRegistry
        self.spacingResolver = spacingResolver
        self.rewriterPipeline = rewriterPipeline
    }

    public func render(
        _ text: String,
        maxWidth: CGFloat,
        theme: MarkdownTheme,
        stateStore: FragmentStateStore?
    ) -> [RenderFragment] {
        // 1. Parse
        var ast = parser.parse(text)

        // 2. Rewrite
        if let rewriter = rewriterPipeline {
            ast = rewriter.rewrite(ast)
        }

        // 3. Render
        let context = RenderContext.initial(
            theme: theme,
            maxWidth: maxWidth,
            stateStore: stateStore ?? FragmentStateStore()
        )

        let childRenderer = ChildRenderer { node, ctx in
            self.renderNode(node, context: ctx)
        }

        let fragments = rendererRegistry
            .renderer(for: ast.nodeType)
            .render(node: ast, context: context, childRenderer: childRenderer)

        // 4. Optimize
        return FragmentOptimizer.optimize(fragments, spacingResolver: spacingResolver, theme: theme)
    }

    private func renderNode(_ node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        let childRenderer = ChildRenderer { child, ctx in
            self.renderNode(child, context: ctx)
        }

        let renderer = rendererRegistry.renderer(for: node.nodeType)
        return renderer.render(node: node, context: context, childRenderer: childRenderer)
    }
}
