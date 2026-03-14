import Foundation

extension MarkdownContract {
    public typealias ParserID = String
    public typealias RendererID = String

    public final class AdapterRegistry {
        private var parsers: [ParserID: MarkdownContractParser] = [:]
        private var renderers: [RendererID: any CanonicalRenderer] = [:]

        public let defaultParserID: ParserID
        public let defaultRendererID: RendererID

        public init(
            defaultParserID: ParserID = "default.parser",
            defaultRendererID: RendererID = "default.renderer"
        ) {
            self.defaultParserID = defaultParserID
            self.defaultRendererID = defaultRendererID
        }

        public func registerParser(_ parser: MarkdownContractParser, id: ParserID) {
            parsers[id] = parser
        }

        public func registerRenderer(_ renderer: any CanonicalRenderer, id: RendererID) {
            renderers[id] = renderer
        }

        public func parser(for id: ParserID?) -> MarkdownContractParser? {
            let resolved = id ?? defaultParserID
            return parsers[resolved]
        }

        public func renderer(for id: RendererID?) -> (any CanonicalRenderer)? {
            let resolved = id ?? defaultRendererID
            return renderers[resolved]
        }

        public var parserIDs: [ParserID] {
            parsers.keys.sorted()
        }

        public var rendererIDs: [RendererID] {
            renderers.keys.sorted()
        }
    }

    public final class UniversalMarkdownKit {
        public let registry: AdapterRegistry

        public init(registry: AdapterRegistry = AdapterRegistry()) {
            self.registry = registry
        }

        public func parse(
            _ markdown: String,
            parserID: ParserID? = nil,
            options: MarkdownContractParserOptions = MarkdownContractParserOptions()
        ) throws -> CanonicalDocument {
            guard let parser = registry.parser(for: parserID) else {
                throw ModelError(
                    code: ModelError.Code.requiredFieldMissing.rawValue,
                    message: "Parser not found: \(parserID ?? registry.defaultParserID)",
                    path: "parserID"
                )
            }

            return parser.parse(markdown, options: options)
        }

        public func render(
            _ markdown: String,
            parserID: ParserID? = nil,
            rendererID: RendererID? = nil,
            parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
            rewritePipeline: CanonicalRewritePipeline = CanonicalRewritePipeline(),
            renderOptions: CanonicalRenderOptions = CanonicalRenderOptions()
        ) throws -> RenderModel {
            let document = try parse(markdown, parserID: parserID, options: parseOptions)

            guard let renderer = registry.renderer(for: rendererID) else {
                throw ModelError(
                    code: ModelError.Code.requiredFieldMissing.rawValue,
                    message: "Renderer not found: \(rendererID ?? registry.defaultRendererID)",
                    path: "rendererID"
                )
            }

            let rewritten = try rewritePipeline.rewrite(document)
            return try renderer.render(document: rewritten, options: renderOptions)
        }
    }
}
