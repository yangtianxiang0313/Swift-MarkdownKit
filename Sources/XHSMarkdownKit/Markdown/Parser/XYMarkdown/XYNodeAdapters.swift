import Foundation
import XYMarkdown

// MARK: - Base Adapter

class XYNodeAdapter: MarkdownNode {
    let markup: Markup
    var nodeType: FragmentNodeType { .document }
    lazy var children: [MarkdownNode] = {
        markup.children.map { XYNodeAdapter.adapt($0) }
    }()

    init(markup: Markup) {
        self.markup = markup
    }

    static func adapt(_ markup: Markup) -> MarkdownNode {
        switch markup {
        case let node as XYMarkdown.Document:
            return XYDocumentNode(markup: node)
        case let node as XYMarkdown.Paragraph:
            return XYParagraphNode(markup: node)
        case let node as XYMarkdown.Heading:
            return XYHeadingNode(markup: node)
        case let node as XYMarkdown.CodeBlock:
            return XYCodeBlockNode(markup: node)
        case let node as XYMarkdown.BlockQuote:
            return XYBlockQuoteNode(markup: node)
        case let node as XYMarkdown.OrderedList:
            return XYOrderedListNode(markup: node)
        case let node as XYMarkdown.UnorderedList:
            return XYUnorderedListNode(markup: node)
        case let node as XYMarkdown.ListItem:
            return XYListItemNode(markup: node)
        case let node as XYMarkdown.Table:
            return XYTableNode(markup: node)
        case let node as XYMarkdown.ThematicBreak:
            return XYThematicBreakNode(markup: node)
        case let node as XYMarkdown.Image:
            return XYImageNode(markup: node)
        case let node as XYMarkdown.Text:
            return XYTextNode(markup: node)
        case let node as XYMarkdown.Strong:
            return XYStrongNode(markup: node)
        case let node as XYMarkdown.Emphasis:
            return XYEmphasisNode(markup: node)
        case let node as XYMarkdown.InlineCode:
            return XYInlineCodeNode(markup: node)
        case let node as XYMarkdown.Link:
            return XYLinkNode(markup: node)
        case let node as XYMarkdown.Strikethrough:
            return XYStrikethroughNode(markup: node)
        case _ as XYMarkdown.SoftBreak:
            return XYSoftBreakNode(markup: markup)
        case _ as XYMarkdown.LineBreak:
            return XYLineBreakNode(markup: markup)
        default:
            return XYNodeAdapter(markup: markup)
        }
    }
}

// MARK: - Block Adapters

final class XYDocumentNode: XYNodeAdapter, DocumentNode {
    override var nodeType: FragmentNodeType { .document }
}

final class XYParagraphNode: XYNodeAdapter, ParagraphNode {
    override var nodeType: FragmentNodeType { .paragraph }
    var inlineChildren: [MarkdownNode] { children }
}

final class XYHeadingNode: XYNodeAdapter, HeadingNode {
    override var nodeType: FragmentNodeType { .heading(level) }
    var level: Int { (markup as? XYMarkdown.Heading)?.level ?? 1 }
    var inlineChildren: [MarkdownNode] { children }
}

final class XYCodeBlockNode: XYNodeAdapter, CodeBlockNode {
    override var nodeType: FragmentNodeType { .codeBlock }
    var code: String { (markup as? XYMarkdown.CodeBlock)?.code ?? "" }
    var language: String? { (markup as? XYMarkdown.CodeBlock)?.language }
}

final class XYBlockQuoteNode: XYNodeAdapter, BlockQuoteNode {
    override var nodeType: FragmentNodeType { .blockQuote }
}

final class XYOrderedListNode: XYNodeAdapter, OrderedListNode {
    override var nodeType: FragmentNodeType { .orderedList }
}

final class XYUnorderedListNode: XYNodeAdapter, UnorderedListNode {
    override var nodeType: FragmentNodeType { .unorderedList }
}

final class XYListItemNode: XYNodeAdapter, ListItemNode {
    override var nodeType: FragmentNodeType { .listItem }
    var checkbox: Bool? {
        guard let item = markup as? XYMarkdown.ListItem,
              let cb = item.checkbox else { return nil }
        return cb == .checked
    }
}

final class XYTableNode: XYNodeAdapter, TableNode {
    override var nodeType: FragmentNodeType { .table }

    var headerCells: [[MarkdownNode]] {
        guard let table = markup as? XYMarkdown.Table else { return [] }
        return table.head.cells.map { cell in
            cell.children.map { XYNodeAdapter.adapt($0) }
        }
    }

    var bodyRows: [[[MarkdownNode]]] {
        guard let table = markup as? XYMarkdown.Table else { return [] }
        return table.body.rows.map { row in
            row.cells.map { cell in
                cell.children.map { XYNodeAdapter.adapt($0) }
            }
        }
    }

    var columnAlignments: [TableColumnAlignment] {
        guard let table = markup as? XYMarkdown.Table else { return [] }
        return table.columnAlignments.map { alignment in
            switch alignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            default: return .none
            }
        }
    }
}

final class XYThematicBreakNode: XYNodeAdapter, ThematicBreakNode {
    override var nodeType: FragmentNodeType { .thematicBreak }
}

final class XYImageNode: XYNodeAdapter, ImageNode {
    override var nodeType: FragmentNodeType { .image }
    var source: String? { (markup as? XYMarkdown.Image)?.source }
    var title: String? { (markup as? XYMarkdown.Image)?.title }
    var altText: String { (markup as? XYMarkdown.Image)?.plainText ?? "" }
}

// MARK: - Inline Adapters

final class XYTextNode: XYNodeAdapter, TextNode {
    var text: String { (markup as? XYMarkdown.Text)?.string ?? "" }
}

final class XYStrongNode: XYNodeAdapter, StrongNode {}
final class XYEmphasisNode: XYNodeAdapter, EmphasisNode {}

final class XYInlineCodeNode: XYNodeAdapter, InlineCodeNode {
    var code: String { (markup as? XYMarkdown.InlineCode)?.code ?? "" }
}

final class XYLinkNode: XYNodeAdapter, LinkNode {
    var destination: String? { (markup as? XYMarkdown.Link)?.destination }
    var title: String? { (markup as? XYMarkdown.Link)?.title }
}

final class XYStrikethroughNode: XYNodeAdapter, StrikethroughNode {}
final class XYSoftBreakNode: XYNodeAdapter, SoftBreakNode {}
final class XYLineBreakNode: XYNodeAdapter, LineBreakNode {}
