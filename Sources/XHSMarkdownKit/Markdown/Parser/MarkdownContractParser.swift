import Foundation

public struct MarkdownContractParserOptions: Sendable, Equatable {
    public var documentId: String
    public var sourceURL: URL?
    public var parseBlockDirectives: Bool
    public var parseSymbolLinks: Bool
    public var parseMinimalDoxygen: Bool
    public var disableSmartOptions: Bool
    public var disableSourcePosition: Bool

    public init(
        documentId: String = "document",
        sourceURL: URL? = nil,
        parseBlockDirectives: Bool = true,
        parseSymbolLinks: Bool = false,
        parseMinimalDoxygen: Bool = false,
        disableSmartOptions: Bool = false,
        disableSourcePosition: Bool = false
    ) {
        self.documentId = documentId
        self.sourceURL = sourceURL
        self.parseBlockDirectives = parseBlockDirectives
        self.parseSymbolLinks = parseSymbolLinks
        self.parseMinimalDoxygen = parseMinimalDoxygen
        self.disableSmartOptions = disableSmartOptions
        self.disableSourcePosition = disableSourcePosition
    }

}

public protocol MarkdownContractParser {
    func parse(_ text: String, options: MarkdownContractParserOptions) -> MarkdownContract.CanonicalDocument
}
