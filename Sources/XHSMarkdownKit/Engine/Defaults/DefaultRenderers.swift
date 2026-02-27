import Foundation
import UIKit
import XYMarkdown

// MARK: - 默认渲染器

// MARK: - DefaultDocumentRenderer

/// Document 渲染器
/// 为每个顶层子节点设置独立的路径，确保 Fragment ID 唯一
public struct DefaultDocumentRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard node is Document else { return [] }
        
        // 为每个子节点设置独立的路径，防止 Fragment ID 冲突
        return childRenderer.renderChildrenWithPath(
            of: node,
            context: context,
            pathPrefix: PathPrefix.document.rawValue
        )
    }
}

// MARK: - DefaultParagraphRenderer

public struct DefaultParagraphRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let paragraph = node as? Paragraph else { return [] }
        
        let attributedString = InlineRenderer.renderInlines(
            node: paragraph,
            context: context
        )
        
        return [
            TextFragment.create(
                fragmentId: context.fragmentId(nodeType: NodeTypeName.para.rawValue, index: 0),
                nodeType: .paragraph,
                attributedString: attributedString,
                context: .from(context, for: TextFragment.self),
                maxWidth: context.maxWidth,
                theme: context.theme
            )
        ]
    }
}

// MARK: - DefaultHeadingRenderer

public struct DefaultHeadingRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let heading = node as? Heading else { return [] }
        
        let level = heading.level
        let headingStyle = context.theme.heading
        
        // 使用 HeadingStyle 的便捷方法
        let font = headingStyle.font(for: level)
        let color = headingStyle.color(for: level)
        let lineHeight = headingStyle.lineHeight(for: level)
        
        let attributedString = InlineRenderer.renderInlines(
            node: heading,
            context: context,
            baseFont: font,
            baseColor: color,
            lineHeight: lineHeight
        )
        
        return [
            TextFragment.create(
                fragmentId: context.fragmentId(nodeType: NodeTypeName.heading(level).rawValue, index: 0),
                nodeType: .heading(level: level),
                attributedString: attributedString,
                context: .from(context, for: TextFragment.self),
                maxWidth: context.maxWidth,
                theme: context.theme
            )
        ]
    }
}

// MARK: - DefaultCodeBlockRenderer

public struct DefaultCodeBlockRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let codeBlock = node as? CodeBlock else { return [] }
        
        let code = codeBlock.code
        let language = codeBlock.language ?? ""
        let fragmentId = context.fragmentId(nodeType: NodeTypeName.code.rawValue, index: 0)
        let interactionState = context.stateStore.getState(CodeBlockInteractionState.self, for: fragmentId)
        
        let content = CodeBlockContent(
            fragmentId: fragmentId,
            code: code,
            language: language,
            isCopied: interactionState.isCopied
        )
        let availableWidth = context.maxWidth - context.indent
        let estimatedSize = CGSize(
            width: availableWidth,
            height: CodeBlockView.calculateHeight(content: content, maxWidth: availableWidth, theme: context.theme)
        )
        
        return [
            ViewFragment(
                fragmentId: context.fragmentId(nodeType: NodeTypeName.code.rawValue, index: 0),
                nodeType: .codeBlock,
                reuseIdentifier: .codeBlockView,
                estimatedSize: estimatedSize,
                context: .from(context, for: ViewFragment.self),
                content: content,
                heightProvider: CodeBlockHeightProvider(content: content),
                makeView: { CodeBlockView() },
                configure: { view, content, theme in
                    (view as? FragmentConfigurable)?.configure(content: content, theme: theme)
                }
            )
        ]
    }
}

/// 代码块内容（原始数据 + 外部状态）
public struct CodeBlockContent {
    public let fragmentId: String
    public let code: String
    public let language: String
    /// 是否显示「已复制」状态（从 StateStore 读取）
    public let isCopied: Bool
    
    public init(fragmentId: String, code: String, language: String, isCopied: Bool = false) {
        self.fragmentId = fragmentId
        self.code = code
        self.language = language
        self.isCopied = isCopied
    }
}

// MARK: - CodeBlockContent Height Calculation

extension CodeBlockContent {
    
    /// 计算代码块的最终显示高度（含高度限制）
    /// - Note: 此方法仅供 Renderer 在创建 Fragment 时调用，计算 estimatedSize
    public func calculateEstimatedHeight(maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat {
        let codeStyle = theme.code
        let padding = codeStyle.block.padding
        let headerHeight = language.isEmpty ? 0 : codeStyle.block.header.height
        
        // 计算代码文本高度
        let codeText = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let availableWidth = maxWidth - padding.left - padding.right
        
        let textSize = (codeText as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: codeStyle.font],
            context: nil
        )
        
        let actualHeight = headerHeight + ceil(textSize.height) + padding.top + padding.bottom
        
        // 应用高度限制
        if let maxHeight = codeStyle.block.maxDisplayHeight {
            return min(actualHeight, maxHeight)
        }
        return actualHeight
    }
}

// MARK: - DefaultBlockQuoteRenderer

public struct DefaultBlockQuoteRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard node is BlockQuote else { return [] }
        
        // 进入引用块
        let childContext = context.enteringBlockQuote()
        
        // 使用 renderChildrenWithPath 确保每个子节点有唯一 ID
        return childRenderer.renderChildrenWithPath(
            of: node,
            context: childContext,
            pathPrefix: PathPrefix.blockQuote.rawValue
        )
    }
}

// MARK: - DefaultOrderedListRenderer

public struct DefaultOrderedListRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let list = node as? OrderedList else { return [] }
        
        let listContext = context.enteringList()
        let startIndex = Int(list.startIndex)
        
        var fragments: [RenderFragment] = []
        for (index, item) in list.listItems.enumerated() {
            let itemNumber = startIndex + index
            let itemContext = listContext
                .appendingPath(PathComponent.listItem(index).rawValue)
                .setting(ListItemIndexKey.self, to: itemNumber)
                .setting(IsOrderedListKey.self, to: true)
            fragments.append(contentsOf: childRenderer.render(item, context: itemContext))
        }
        
        return fragments
    }
}

// MARK: - DefaultUnorderedListRenderer

public struct DefaultUnorderedListRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let list = node as? UnorderedList else { return [] }
        
        let listContext = context.enteringList()
        
        var fragments: [RenderFragment] = []
        for (index, item) in list.listItems.enumerated() {
            let itemContext = listContext
                .appendingPath(PathComponent.listItem(index).rawValue)
                .setting(ListItemIndexKey.self, to: index)
                .setting(IsOrderedListKey.self, to: false)
            fragments.append(contentsOf: childRenderer.render(item, context: itemContext))
        }
        
        return fragments
    }
}

// MARK: - DefaultListItemRenderer

public struct DefaultListItemRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let listItem = node as? ListItem else { return [] }
        
        let theme = context.theme
        let listStyle = theme.list
        let isOrdered = context[IsOrderedListKey.self]
        let itemIndex = context[ListItemIndexKey.self]
        let listDepth = context[ListDepthKey.self]
        
        // 渲染子内容（通常是段落）
        var fragments: [RenderFragment] = []
        
        for (childIndex, child) in listItem.children.enumerated() {
            let childContext = context.appendingPath(PathComponent.child(childIndex).rawValue)
            let childFragments = childRenderer.render(child, context: childContext)
            
            // 只在第一个子节点前面加项目符号
            if childIndex == 0 {
                for fragment in childFragments {
                    if let textFragment = fragment as? TextFragment {
                        let prefixedText = addListPrefix(
                            to: textFragment.attributedString,
                            isOrdered: isOrdered,
                            index: itemIndex,
                            depth: listDepth,
                            listStyle: listStyle,
                            theme: theme
                        )
                        fragments.append(TextFragment.create(
                            fragmentId: textFragment.fragmentId,
                            nodeType: textFragment.nodeType,
                            attributedString: prefixedText,
                            context: textFragment.context,
                            maxWidth: context.maxWidth,
                            theme: theme
                        ))
                    } else {
                        fragments.append(fragment)
                    }
                }
            } else {
                fragments.append(contentsOf: childFragments)
            }
        }
        
        return fragments
    }
    
    private func addListPrefix(
        to text: NSAttributedString,
        isOrdered: Bool,
        index: Int,
        depth: Int,
        listStyle: MarkdownTheme.ListStyle,
        theme: MarkdownTheme
    ) -> NSAttributedString {
        // 生成项目符号
        let bullet: String
        if isOrdered {
            // index 已经是 1-based 的序号（来自 list.startIndex + 枚举索引）
            bullet = "\(index). "
        } else {
            // 使用 theme 中配置的符号
            bullet = listStyle.unordered.symbol(for: depth) + " "
        }
        
        // 创建带项目符号的文本
        let result = NSMutableAttributedString()
        
        // 使用与文本相同的属性
        var bulletAttrs: [NSAttributedString.Key: Any] = [:]
        if text.length > 0 {
            bulletAttrs = text.attributes(at: 0, effectiveRange: nil)
        } else {
            bulletAttrs = [
                .font: theme.body.font,
                .foregroundColor: theme.body.color
            ]
        }
        
        result.append(NSAttributedString(string: bullet, attributes: bulletAttrs))
        result.append(text)
        
        return result
    }
}

// MARK: - List Context Keys

/// 列表项索引
public enum ListItemIndexKey: ContextKey {
    public static var defaultValue: Int { 0 }
}

/// 是否有序列表
public enum IsOrderedListKey: ContextKey {
    public static var defaultValue: Bool { false }
}

// MARK: - DefaultTableRenderer

public struct DefaultTableRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let table = node as? Table else { return [] }
        
        // 提取表格数据（使用 context 来渲染行内样式）
        let data = extractTableData(table, context: context)
        
        // 计算估算高度
        let estimatedSize = CGSize(
            width: context.maxWidth - context.indent,
            height: data.calculateEstimatedHeight(maxWidth: context.maxWidth - context.indent, theme: context.theme)
        )
        
        return [
            ViewFragment(
                fragmentId: context.fragmentId(nodeType: NodeTypeName.table.rawValue, index: 0),
                nodeType: .table,
                reuseIdentifier: .markdownTableView,
                estimatedSize: estimatedSize,
                context: .from(context, for: ViewFragment.self),
                content: data,
                heightProvider: TableHeightProvider(data: data),
                makeView: { MarkdownTableView() },
                configure: { view, content, theme in
                    (view as? FragmentConfigurable)?.configure(content: content, theme: theme)
                }
            )
        ]
    }
    
    private func extractTableData(_ table: Table, context: RenderContext) -> TableData {
        var headers: [NSAttributedString] = []
        var rows: [[NSAttributedString]] = []
        var alignments: [Table.ColumnAlignment?] = []
        
        let tableStyle = context.theme.table
        
        // 解析表头
        let head = table.head
        headers = head.cells.map { cell in
            extractCellContent(cell, context: context, font: tableStyle.headerFont)
        }
        
        // 解析对齐方式
        alignments = table.columnAlignments
        
        // 解析数据行
        rows = table.body.rows.map { row in
            row.cells.map { cell in
                extractCellContent(cell, context: context, font: tableStyle.font)
            }
        }
        
        return TableData(headers: headers, rows: rows, alignments: alignments)
    }
    
    private func extractCellContent(_ cell: Table.Cell, context: RenderContext, font: UIFont) -> NSAttributedString {
        // 使用 InlineRenderer 处理单元格内容，支持 Strong/Emphasis/Link 等
        return InlineRenderer.renderInlines(
            node: cell,
            context: context,
            baseFont: font,
            baseColor: context.theme.table.textColor,
            lineHeight: nil
        )
    }
}

/// 表格数据
public struct TableData {
    public let headers: [NSAttributedString]
    public let rows: [[NSAttributedString]]
    public let alignments: [Table.ColumnAlignment?]
    
    public init(
        headers: [NSAttributedString],
        rows: [[NSAttributedString]],
        alignments: [Table.ColumnAlignment?]
    ) {
        self.headers = headers
        self.rows = rows
        self.alignments = alignments
    }
}

// MARK: - TableData Height Calculation

extension TableData {
    
    /// 计算表格的最终显示高度（含高度限制）
    /// - Note: 此方法仅供 Renderer 在创建 Fragment 时调用，计算 estimatedSize
    public func calculateEstimatedHeight(maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat {
        let tableStyle = theme.table
        
        // 计算表格实际高度
        // 表头高度 + 数据行高度 + 边框
        let headerRowHeight = tableStyle.minRowHeight
        let dataRowsHeight = CGFloat(rows.count) * tableStyle.minRowHeight
        let borderHeight = tableStyle.borderWidth * CGFloat(rows.count + 2) // 上边框 + 行分隔线 + 下边框
        
        let actualHeight = headerRowHeight + dataRowsHeight + borderHeight
        
        // 应用高度限制
        if let maxHeight = tableStyle.maxDisplayHeight {
            return min(actualHeight, maxHeight)
        }
        return actualHeight
    }
}

// MARK: - DefaultThematicBreakRenderer

public struct DefaultThematicBreakRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard node is ThematicBreak else { return [] }
        
        let breakStyle = context.theme.thematicBreak
        
        return [
            ViewFragment(
                fragmentId: context.fragmentId(nodeType: NodeTypeName.hr.rawValue, index: 0),
                nodeType: .thematicBreak,
                reuseIdentifier: .thematicBreakView,
                estimatedSize: CGSize(
                    width: context.maxWidth - context.indent,
                    height: breakStyle.height + breakStyle.verticalPadding * 2
                ),
                context: .from(context, for: ViewFragment.self),
                content: (),  // ThematicBreak 没有内容
                makeView: { ThematicBreakView() },
                configure: { view, content, theme in
                    (view as? FragmentConfigurable)?.configure(content: content, theme: theme)
                }
            )
        ]
    }
}

// MARK: - DefaultImageRenderer

public struct DefaultImageRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        guard let image = node as? Image else { return [] }
        
        let source = image.source ?? ""
        let alt = image.title ?? ""
        let imageStyle = context.theme.image
        
        let content = ImageContent(source: source, alt: alt)
        
        return [
            ViewFragment(
                fragmentId: context.fragmentId(nodeType: NodeTypeName.img.rawValue, index: 0),
                nodeType: .image,
                reuseIdentifier: .markdownImageView,
                estimatedSize: CGSize(
                    width: min(imageStyle.maxWidth, context.maxWidth - context.indent),
                    height: imageStyle.placeholderHeight
                ),
                context: .from(context, for: ViewFragment.self),
                content: content,
                makeView: { MarkdownImageView() },
                configure: { view, content, theme in
                    (view as? FragmentConfigurable)?.configure(content: content, theme: theme)
                }
            )
        ]
    }
}

/// 图片内容
public struct ImageContent {
    public let source: String
    public let alt: String
}
