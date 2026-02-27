//
//  MarkdownNodeType.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import Foundation
import XYMarkdown

/// 节点类型标识
/// 标准节点使用预定义的 case，自定义节点使用 .custom("identifier")
public enum MarkdownNodeType: Hashable {
    // 块级
    case document
    case heading(level: Int)  // 携带层级信息，省去渲染器内部 downcast
    case paragraph
    case blockQuote
    case codeBlock
    case orderedList
    case unorderedList
    case listItem
    case table
    case thematicBreak
    case htmlBlock
    
    // 间距（内部使用）
    case spacing
    
    // 行内
    case text
    case strong
    case emphasis
    case strikethrough
    case inlineCode
    case link
    case image
    case lineBreak
    case softBreak
    case inlineHTML
    
    // 任务列表
    case taskListItem(checked: Bool)
    
    // 自定义（任意标识符）
    case customBlock(String)
    case customInline(String)
    
    /// 从 XYMarkdown 的 Markup 节点推导类型（内部使用）
    public static func from(_ node: Markup) -> MarkdownNodeType {
        switch node {
        case let h as Heading:
            return .heading(level: h.level)
        case is Paragraph:
            return .paragraph
        case is BlockQuote:
            return .blockQuote
        case is CodeBlock:
            return .codeBlock
        case is OrderedList:
            return .orderedList
        case is UnorderedList:
            return .unorderedList
        case is ListItem:
            return .listItem
        case is Table:
            return .table
        case is ThematicBreak:
            return .thematicBreak
        case is Strong:
            return .strong
        case is Emphasis:
            return .emphasis
        case is Strikethrough:
            return .strikethrough
        case is InlineCode:
            return .inlineCode
        case is Link:
            return .link
        case is Image:
            return .image
        case is Text:
            return .text
        case is LineBreak:
            return .lineBreak
        case is SoftBreak:
            return .softBreak
        case is InlineHTML:
            return .inlineHTML
        case is HTMLBlock:
            return .htmlBlock
        case is Document:
            return .document
        default:
            // 未知节点类型，当作 document 处理（递归渲染子节点）
            return .document
        }
    }
    
    /// 是否为块级节点
    public var isBlock: Bool {
        switch self {
        case .document, .heading, .paragraph, .blockQuote, .codeBlock,
             .orderedList, .unorderedList, .listItem, .table, .thematicBreak,
             .htmlBlock, .taskListItem, .customBlock, .spacing:
            return true
        default:
            return false
        }
    }
    
    /// 是否为行内节点
    public var isInline: Bool {
        !isBlock
    }
}
