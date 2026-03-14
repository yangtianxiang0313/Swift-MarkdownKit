import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public enum MarkdownnAdapter {
    public static let parserID: MarkdownContract.ParserID = "markdownn.default.parser"
    public static let rendererID: MarkdownContract.RendererID = "markdownn.default.renderer"

    public static func install(into registry: MarkdownContract.AdapterRegistry) {
        registry.registerParser(XYMarkdownContractParser(), id: parserID)
        registry.registerRenderer(MarkdownContract.DefaultCanonicalRenderer(), id: rendererID)
    }

    public static func makeEngine(
        rewritePipeline: MarkdownContract.CanonicalRewritePipeline = .init()
    ) -> MarkdownContractEngine {
        MarkdownContractEngine(
            parser: XYMarkdownContractParser(),
            rewritePipeline: rewritePipeline,
            renderer: MarkdownContract.DefaultCanonicalRenderer()
        )
    }
}
