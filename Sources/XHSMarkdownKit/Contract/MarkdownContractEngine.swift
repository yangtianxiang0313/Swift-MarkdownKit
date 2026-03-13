import Foundation

public struct MarkdownContractEngine {
    public let parser: MarkdownContractParser
    public let rewritePipeline: MarkdownContract.CanonicalRewritePipeline
    public let renderer: any MarkdownContract.CanonicalRenderer

    public init(
        parser: MarkdownContractParser = XYMarkdownContractParser(),
        rewritePipeline: MarkdownContract.CanonicalRewritePipeline = .init(),
        renderer: any MarkdownContract.CanonicalRenderer = MarkdownContract.DefaultCanonicalRenderer()
    ) {
        self.parser = parser
        self.rewritePipeline = rewritePipeline
        self.renderer = renderer
    }

    public func parse(
        _ markdown: String,
        options: MarkdownContractParserOptions = MarkdownContractParserOptions()
    ) -> MarkdownContract.CanonicalDocument {
        parser.parse(markdown, options: options)
    }

    public func transform(_ document: MarkdownContract.CanonicalDocument) throws -> MarkdownContract.CanonicalDocument {
        try rewritePipeline.rewrite(document)
    }

    public func render(
        _ document: MarkdownContract.CanonicalDocument,
        options: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) throws -> MarkdownContract.RenderModel {
        let rewritten = try transform(document)
        return try renderer.render(document: rewritten, options: options)
    }

    public func render(
        _ markdown: String,
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) throws -> MarkdownContract.RenderModel {
        let document = parse(markdown, options: parseOptions)
        return try render(document, options: renderOptions)
    }
}
