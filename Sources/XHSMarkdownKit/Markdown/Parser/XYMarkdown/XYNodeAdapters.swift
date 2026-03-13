import Foundation
import XYMarkdown

public final class XYNodeAdapterFactory {
    public typealias AdapterBuilder = (Markup, XYNodeAdapterFactory) -> MarkdownNode

    private var builders: [ObjectIdentifier: AdapterBuilder] = [:]

    public init(registerDefaults: Bool = true) {
        if registerDefaults {
            registerDefaultAdapters()
        }
    }

    public func register<M: Markup>(
        _ markupType: M.Type,
        builder: @escaping (M, XYNodeAdapterFactory) -> MarkdownNode
    ) {
        builders[ObjectIdentifier(markupType)] = { markup, factory in
            guard let typedMarkup = markup as? M else {
                preconditionFailure("Adapter expected \(M.self), got \(type(of: markup))")
            }
            return builder(typedMarkup, factory)
        }
    }

    public func adapt(_ markup: Markup) -> MarkdownNode {
        let key = ObjectIdentifier(type(of: markup))
        guard let builder = builders[key] else {
            return XYUnknownNode(markup: markup, factory: self)
        }
        return builder(markup, self)
    }

    public static func makeDefault() -> XYNodeAdapterFactory {
        XYNodeAdapterFactory()
    }

    private func registerDefaultAdapters() {
        register(XYMarkdown.Document.self) { XYDocumentNode(markup: $0, factory: $1) }
        register(XYMarkdown.Paragraph.self) { XYParagraphNode(markup: $0, factory: $1) }
        register(XYMarkdown.Heading.self) { XYHeadingNode(markup: $0, factory: $1) }
        register(XYMarkdown.CodeBlock.self) { XYCodeBlockNode(markup: $0, factory: $1) }
        register(XYMarkdown.BlockQuote.self) { XYBlockQuoteNode(markup: $0, factory: $1) }
        register(XYMarkdown.OrderedList.self) { XYOrderedListNode(markup: $0, factory: $1) }
        register(XYMarkdown.UnorderedList.self) { XYUnorderedListNode(markup: $0, factory: $1) }
        register(XYMarkdown.ListItem.self) { XYListItemNode(markup: $0, factory: $1) }
        register(XYMarkdown.Table.self) { XYTableNode(markup: $0, factory: $1) }
        register(XYMarkdown.ThematicBreak.self) { XYThematicBreakNode(markup: $0, factory: $1) }
        register(XYMarkdown.Image.self) { XYImageNode(markup: $0, factory: $1) }
        register(XYMarkdown.Text.self) { XYTextNode(markup: $0, factory: $1) }
        register(XYMarkdown.Strong.self) { XYStrongNode(markup: $0, factory: $1) }
        register(XYMarkdown.Emphasis.self) { XYEmphasisNode(markup: $0, factory: $1) }
        register(XYMarkdown.InlineCode.self) { XYInlineCodeNode(markup: $0, factory: $1) }
        register(XYMarkdown.Link.self) { XYLinkNode(markup: $0, factory: $1) }
        register(XYMarkdown.Strikethrough.self) { XYStrikethroughNode(markup: $0, factory: $1) }
        register(XYMarkdown.SoftBreak.self) { XYSoftBreakNode(markup: $0, factory: $1) }
        register(XYMarkdown.LineBreak.self) { XYLineBreakNode(markup: $0, factory: $1) }
    }
}

// MARK: - Base Adapters

class XYNodeAdapter: MarkdownNode {
    let factory: XYNodeAdapterFactory
    var nodeType: FragmentNodeType { .document }
    var children: [MarkdownNode] { [] }

    init(factory: XYNodeAdapterFactory) {
        self.factory = factory
    }
}

class XYTypedNodeAdapter<Source: Markup>: XYNodeAdapter {
    let markup: Source
    override var children: [MarkdownNode] {
        markup.children.map { factory.adapt($0) }
    }

    init(markup: Source, factory: XYNodeAdapterFactory) {
        self.markup = markup
        super.init(factory: factory)
    }
}

final class XYUnknownNode: XYNodeAdapter {
    private let markup: Markup
    override var children: [MarkdownNode] {
        markup.children.map { factory.adapt($0) }
    }

    init(markup: Markup, factory: XYNodeAdapterFactory) {
        self.markup = markup
        super.init(factory: factory)
    }
}

// MARK: - Block Adapters

final class XYDocumentNode: XYTypedNodeAdapter<XYMarkdown.Document>, DocumentNode {
    override var nodeType: FragmentNodeType { .document }
}

final class XYParagraphNode: XYTypedNodeAdapter<XYMarkdown.Paragraph>, ParagraphNode {
    override var nodeType: FragmentNodeType { .paragraph }
    var inlineChildren: [MarkdownNode] { children }
}

final class XYHeadingNode: XYTypedNodeAdapter<XYMarkdown.Heading>, HeadingNode {
    override var nodeType: FragmentNodeType { .heading(level) }
    var level: Int { markup.level }
    var inlineChildren: [MarkdownNode] { children }
}

final class XYCodeBlockNode: XYTypedNodeAdapter<XYMarkdown.CodeBlock>, CodeBlockNode {
    override var nodeType: FragmentNodeType { .codeBlock }
    var code: String { markup.code }
    var language: String? { markup.language }
}

final class XYBlockQuoteNode: XYTypedNodeAdapter<XYMarkdown.BlockQuote>, BlockQuoteNode {
    override var nodeType: FragmentNodeType { .blockQuote }
}

final class XYOrderedListNode: XYTypedNodeAdapter<XYMarkdown.OrderedList>, OrderedListNode {
    override var nodeType: FragmentNodeType { .orderedList }
}

final class XYUnorderedListNode: XYTypedNodeAdapter<XYMarkdown.UnorderedList>, UnorderedListNode {
    override var nodeType: FragmentNodeType { .unorderedList }
}

final class XYListItemNode: XYTypedNodeAdapter<XYMarkdown.ListItem>, ListItemNode {
    override var nodeType: FragmentNodeType { .listItem }
    var checkbox: Bool? {
        guard let checkbox = markup.checkbox else { return nil }
        return checkbox == .checked
    }
}

final class XYTableNode: XYTypedNodeAdapter<XYMarkdown.Table>, TableNode {
    override var nodeType: FragmentNodeType { .table }

    var headerCells: [[MarkdownNode]] {
        markup.head.cells.map { cell in
            cell.children.map { factory.adapt($0) }
        }
    }

    var bodyRows: [[[MarkdownNode]]] {
        markup.body.rows.map { row in
            row.cells.map { cell in
                cell.children.map { factory.adapt($0) }
            }
        }
    }

    var columnAlignments: [TableColumnAlignment] {
        markup.columnAlignments.map { $0?.xhsAlignment ?? .none }
    }
}

final class XYThematicBreakNode: XYTypedNodeAdapter<XYMarkdown.ThematicBreak>, ThematicBreakNode {
    override var nodeType: FragmentNodeType { .thematicBreak }
}

final class XYImageNode: XYTypedNodeAdapter<XYMarkdown.Image>, ImageNode {
    override var nodeType: FragmentNodeType { .image }
    var source: String? { markup.source }
    var title: String? { markup.title }
    var altText: String { markup.plainText }
}

// MARK: - Inline Adapters

final class XYTextNode: XYTypedNodeAdapter<XYMarkdown.Text>, TextNode {
    var text: String { markup.string }
}

final class XYStrongNode: XYTypedNodeAdapter<XYMarkdown.Strong>, StrongNode {}
final class XYEmphasisNode: XYTypedNodeAdapter<XYMarkdown.Emphasis>, EmphasisNode {}

final class XYInlineCodeNode: XYTypedNodeAdapter<XYMarkdown.InlineCode>, InlineCodeNode {
    var code: String { markup.code }
}

final class XYLinkNode: XYTypedNodeAdapter<XYMarkdown.Link>, LinkNode {
    var destination: String? { markup.destination }
    var title: String? { markup.title }
}

final class XYStrikethroughNode: XYTypedNodeAdapter<XYMarkdown.Strikethrough>, StrikethroughNode {}
final class XYSoftBreakNode: XYTypedNodeAdapter<XYMarkdown.SoftBreak>, SoftBreakNode {}
final class XYLineBreakNode: XYTypedNodeAdapter<XYMarkdown.LineBreak>, LineBreakNode {}

private extension XYMarkdown.Table.ColumnAlignment {
    var xhsAlignment: TableColumnAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        @unknown default: return .none
        }
    }
}
