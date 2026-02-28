import Foundation
import XYMarkdown

public struct XYMarkdownParser: MarkdownParser {

    public init() {}

    public func parse(_ text: String) -> MarkdownNode {
        let document = Document(parsing: text)
        return XYDocumentNode(markup: document)
    }
}
