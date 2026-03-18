import Foundation

public struct MarkdownContractEngine {
    public let parser: MarkdownContractParser?
    public let rewritePipeline: MarkdownContract.CanonicalRewritePipeline?
    public let renderer: (any MarkdownContract.CanonicalRenderer)?

    public init(
        parser: MarkdownContractParser? = nil,
        rewritePipeline: MarkdownContract.CanonicalRewritePipeline? = nil,
        renderer: (any MarkdownContract.CanonicalRenderer)? = nil
    ) {
        self.parser = parser
        self.rewritePipeline = rewritePipeline
        self.renderer = renderer
    }

    public func parse(
        _ markdown: String,
        options: MarkdownContractParserOptions = MarkdownContractParserOptions()
    ) throws -> MarkdownContract.CanonicalDocument {
        guard let parser else {
            throw MarkdownContract.ModelError(
                code: .requiredFieldMissing,
                message: "Parser not configured",
                path: "MarkdownContractEngine.parser"
            )
        }
        return try parser.parse(markdown, options: options)
    }

    public func transform(_ document: MarkdownContract.CanonicalDocument) throws -> MarkdownContract.CanonicalDocument {
        try resolvedRewritePipeline().rewrite(document)
    }

    public func render(
        _ document: MarkdownContract.CanonicalDocument,
        options: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) throws -> MarkdownContract.RenderModel {
        guard let renderer else {
            throw MarkdownContract.ModelError(
                code: .requiredFieldMissing,
                message: "Renderer not configured",
                path: "MarkdownContractEngine.renderer"
            )
        }
        let rewritten = try transform(document)
        return try renderer.render(document: rewritten, options: options)
    }

    public func render(
        _ markdown: String,
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) throws -> MarkdownContract.RenderModel {
        let document = try parse(markdown, options: parseOptions)
        return try render(document, options: renderOptions)
    }

    private func resolvedRewritePipeline() throws -> MarkdownContract.CanonicalRewritePipeline {
        if let rewritePipeline {
            return rewritePipeline
        }

        let parserRegistry = (parser as? MarkdownContract.NodeSpecRegistryProviding)?.nodeSpecRegistry
        let rendererRegistry = (renderer as? MarkdownContract.NodeSpecRegistryProviding)?.nodeSpecRegistry

        if let parserRegistry, let rendererRegistry,
           !parserRegistry.isEquivalent(to: rendererRegistry) {
            throw MarkdownContract.ModelError(
                code: .schemaInvalid,
                message: "Parser and renderer must share the same NodeSpecRegistry when rewritePipeline is not provided",
                path: "MarkdownContractEngine.rewritePipeline",
                details: [
                    "parserSpecCount": .int(parserRegistry.specCount),
                    "rendererSpecCount": .int(rendererRegistry.specCount)
                ]
            )
        }

        if let sharedRegistry = parserRegistry ?? rendererRegistry {
            return MarkdownContract.CanonicalRewritePipeline(nodeSpecRegistry: sharedRegistry)
        }

        return MarkdownContract.CanonicalRewritePipeline()
    }
}
