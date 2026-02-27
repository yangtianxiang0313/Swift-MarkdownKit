//
//  BlockSpacingResolving.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit
import XYMarkdown

/// 块级元素间距计算协议
///
/// 使用场景：
/// - 紧凑场景需要紧凑间距（段落间距 26pt、列表间距 6pt）
/// - 笔记详情需要宽松间距（段落间距 32pt）
/// - 搜索结果需要更紧凑的间距
///
/// 通过协议化，各场景只需实现自己的 Resolver，无需 fork 整个渲染器。
public protocol BlockSpacingResolving {
    /// 计算两个相邻块级节点之间的间距
    ///
    /// - Parameters:
    ///   - previous: 前一个块级节点
    ///   - current: 当前块级节点
    ///   - theme: 当前主题（可从中读取间距 Token）
    /// - Returns: 间距值（pt）
    func spacing(after previous: Markup, before current: Markup, theme: MarkdownTheme) -> CGFloat
}

/// 默认间距规则
///
/// 所有间距值从 MarkdownTheme 读取，不再硬编码。
public struct DefaultBlockSpacingResolver: BlockSpacingResolving {
    
    public init() {}
    
    public func spacing(after previous: Markup, before current: Markup, theme: MarkdownTheme) -> CGFloat {
        switch current {
        case is Paragraph:
            if previous is Heading {
                return theme.spacing.headingAfter
            }
            if previous is BlockQuote {
                return theme.spacing.blockQuoteOther
            }
            return theme.spacing.paragraph
            
        case let heading as Heading:
            let index = heading.level - 1
            if index >= 0 && index < theme.spacing.headingBefore.count {
                return theme.spacing.headingBefore[index]
            }
            return theme.spacing.paragraph
            
        case is ThematicBreak, is CodeBlock:
            return theme.spacing.paragraph
            
        case is BlockQuote:
            if previous is BlockQuote {
                return theme.spacing.blockQuoteBetween
            }
            if previous is Heading {
                return theme.spacing.headingAfter
            }
            return theme.spacing.blockQuoteOther
            
        case is UnorderedList, is OrderedList:
            if previous is Heading {
                return theme.spacing.headingAfter
            }
            if previous is Paragraph {
                return theme.spacing.listAfterText
            }
            if previous is BlockQuote {
                return theme.spacing.blockQuoteOther
            }
            return theme.spacing.paragraph
            
        case is Table:
            if previous is Heading {
                return theme.spacing.headingAfter
            }
            return theme.spacing.paragraph
            
        default:
            return 0
        }
    }
}

/// 紧凑间距规则（示例）
public struct CompactBlockSpacingResolver: BlockSpacingResolving {
    
    /// 间距缩减系数
    public static let spacingMultiplier: CGFloat = 0.5
    
    public init() {}
    
    public func spacing(after previous: Markup, before current: Markup, theme: MarkdownTheme) -> CGFloat {
        // 紧凑场景：所有间距按系数缩减
        let defaultResolver = DefaultBlockSpacingResolver()
        return defaultResolver.spacing(after: previous, before: current, theme: theme) * Self.spacingMultiplier
    }
}
