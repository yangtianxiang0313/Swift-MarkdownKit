//
//  ReuseIdentifier.swift
//  XHSMarkdownKit
//

import Foundation

/// View 复用标识符
/// 用于 MarkdownContainerView 的复用池和 View 类型匹配
public enum ReuseIdentifier: String {
    case codeBlockView = "CodeBlockView"
    case markdownTableView = "MarkdownTableView"
    case thematicBreakView = "ThematicBreakView"
    case markdownImageView = "MarkdownImageView"
    case textView = "text"
    case blockQuoteText = "blockQuoteText"
    case spacing = "spacing"
    /// 自定义代码块（Example 中的 CustomCodeBlockRenderer）
    case customCodeBlock = "CustomCodeBlock"
}
