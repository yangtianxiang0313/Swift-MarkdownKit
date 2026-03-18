import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public enum MarkdownnAdapter {
    public static let parserID: MarkdownContract.ParserID = "markdownn.default.parser"
    public static let rendererID: MarkdownContract.RendererID = "markdownn.default.renderer"

    public static func install(
        into registry: MarkdownContract.AdapterRegistry,
        nodeSpecRegistry: MarkdownContract.NodeSpecRegistry = .core(),
        canonicalRendererRegistry: MarkdownContract.CanonicalRendererRegistry = .makeDefault()
    ) {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: nodeSpecRegistry)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: canonicalRendererRegistry,
            nodeSpecRegistry: nodeSpecRegistry
        )
        registry.registerParser(parser, id: parserID)
        registry.registerRenderer(renderer, id: rendererID)
    }

    public static func makeEngine(
        rewritePipeline: MarkdownContract.CanonicalRewritePipeline? = nil,
        nodeSpecRegistry: MarkdownContract.NodeSpecRegistry = .core(),
        canonicalRendererRegistry: MarkdownContract.CanonicalRendererRegistry = .makeDefault()
    ) -> MarkdownContractEngine {
        MarkdownContractEngine(
            parser: XYMarkdownContractParser(nodeSpecRegistry: nodeSpecRegistry),
            rewritePipeline: rewritePipeline,
            renderer: MarkdownContract.DefaultCanonicalRenderer(
                registry: canonicalRendererRegistry,
                nodeSpecRegistry: nodeSpecRegistry
            )
        )
    }
}
