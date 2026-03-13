import Foundation

// MARK: - Base Protocol

public protocol MarkdownNode: AnyObject {
    var nodeType: FragmentNodeType { get }
    var children: [MarkdownNode] { get }
}

// MARK: - Protocol Conformance Check

extension MarkdownNode {
    /// 检查节点是否符合指定协议
    public func `conforms`<T>(to type: T.Type) -> Bool {
        return self is T
    }
}

// MARK: - Specific Node Protocols

public protocol DocumentNode: MarkdownNode {}
public protocol ParagraphNode: MarkdownNode {
    var inlineChildren: [MarkdownNode] { get }
}
public protocol HeadingNode: MarkdownNode {
    var level: Int { get }
    var inlineChildren: [MarkdownNode] { get }
}
public protocol CodeBlockNode: MarkdownNode {
    var code: String { get }
    var language: String? { get }
}
public protocol BlockQuoteNode: MarkdownNode {}
public protocol OrderedListNode: MarkdownNode {}
public protocol UnorderedListNode: MarkdownNode {}
public protocol ListItemNode: MarkdownNode {
    /// nil = 普通列表项，true = 已勾选，false = 未勾选
    var checkbox: Bool? { get }
}
public protocol TableNode: MarkdownNode {
    var headerCells: [[MarkdownNode]] { get }
    var bodyRows: [[[MarkdownNode]]] { get }
    var columnAlignments: [TableColumnAlignment] { get }
}
public protocol ThematicBreakNode: MarkdownNode {}
public protocol ImageNode: MarkdownNode {
    var source: String? { get }
    var title: String? { get }
    var altText: String { get }
}

// MARK: - Inline Node Protocols

public protocol TextNode: MarkdownNode {
    var text: String { get }
}
public protocol StrongNode: MarkdownNode {}
public protocol EmphasisNode: MarkdownNode {}
public protocol InlineCodeNode: MarkdownNode {
    var code: String { get }
}
public protocol LinkNode: MarkdownNode {
    var destination: String? { get }
    var title: String? { get }
}
public protocol StrikethroughNode: MarkdownNode {}
public protocol SoftBreakNode: MarkdownNode {}
public protocol LineBreakNode: MarkdownNode {}

// MARK: - Supporting Types

public enum TableColumnAlignment: Equatable {
    case left, center, right, none
}
