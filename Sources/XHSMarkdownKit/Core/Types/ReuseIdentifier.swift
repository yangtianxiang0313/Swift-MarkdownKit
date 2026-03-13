import Foundation

public struct ReuseIdentifier: Hashable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension ReuseIdentifier {
    static let contractTextView = ReuseIdentifier(rawValue: "contract.textView")
    static let contractBlockQuoteContainer = ReuseIdentifier(rawValue: "contract.blockQuoteContainer")
    static let contractCodeBlockView = ReuseIdentifier(rawValue: "contract.codeBlockView")
    static let contractTableView = ReuseIdentifier(rawValue: "contract.tableView")
    static let contractThematicBreakView = ReuseIdentifier(rawValue: "contract.thematicBreakView")
    static let contractImageView = ReuseIdentifier(rawValue: "contract.imageView")
}
