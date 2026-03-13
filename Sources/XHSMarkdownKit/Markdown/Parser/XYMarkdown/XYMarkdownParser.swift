import Foundation
import XYMarkdown

public struct XYMarkdownParser: MarkdownParser {
    public let adapterFactory: XYNodeAdapterFactory

    public init(adapterFactory: XYNodeAdapterFactory = .makeDefault()) {
        self.adapterFactory = adapterFactory
    }

    public func parse(_ text: String) -> MarkdownNode {
        let document = Document(parsing: text)
        return adapterFactory.adapt(document)
    }
}
