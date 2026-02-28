import Foundation

public struct ReuseIdentifier: Hashable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension ReuseIdentifier {
    static let textView = ReuseIdentifier(rawValue: "textView")
    static let blockQuoteText = ReuseIdentifier(rawValue: "blockQuoteText")
    static let blockQuoteContainer = ReuseIdentifier(rawValue: "blockQuoteContainer")
    static let codeBlockView = ReuseIdentifier(rawValue: "codeBlockView")
    static let markdownTableView = ReuseIdentifier(rawValue: "markdownTableView")
    static let thematicBreakView = ReuseIdentifier(rawValue: "thematicBreakView")
    static let markdownImageView = ReuseIdentifier(rawValue: "markdownImageView")
}
