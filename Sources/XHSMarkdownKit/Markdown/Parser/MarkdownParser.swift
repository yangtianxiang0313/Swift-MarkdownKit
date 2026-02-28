import Foundation

public protocol MarkdownParser {
    func parse(_ text: String) -> MarkdownNode
}
