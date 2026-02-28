import Foundation

public extension FragmentNodeType {
    static let document = FragmentNodeType(rawValue: "document")
    static let paragraph = FragmentNodeType(rawValue: "paragraph")
    static let heading1 = FragmentNodeType(rawValue: "heading.1")
    static let heading2 = FragmentNodeType(rawValue: "heading.2")
    static let heading3 = FragmentNodeType(rawValue: "heading.3")
    static let heading4 = FragmentNodeType(rawValue: "heading.4")
    static let heading5 = FragmentNodeType(rawValue: "heading.5")
    static let heading6 = FragmentNodeType(rawValue: "heading.6")
    static let codeBlock = FragmentNodeType(rawValue: "codeBlock")
    static let table = FragmentNodeType(rawValue: "table")
    static let thematicBreak = FragmentNodeType(rawValue: "thematicBreak")
    static let image = FragmentNodeType(rawValue: "image")
    static let orderedList = FragmentNodeType(rawValue: "list.ordered")
    static let unorderedList = FragmentNodeType(rawValue: "list.unordered")
    static let listItem = FragmentNodeType(rawValue: "listItem")
    static let blockQuote = FragmentNodeType(rawValue: "blockQuote")

    static func heading(_ level: Int) -> FragmentNodeType {
        FragmentNodeType(rawValue: "heading.\(level)")
    }
}
