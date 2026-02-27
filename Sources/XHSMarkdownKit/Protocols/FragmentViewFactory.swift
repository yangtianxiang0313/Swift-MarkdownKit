//
//  FragmentViewFactory.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - FragmentHeightProvider

/// 按动画进度计算高度的提供者（协议，非闭包）
/// 遵循「少用闭包、多用协议」设计原则
public protocol FragmentHeightProvider {
    func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat
}

// MARK: - TextHeightProvider

/// 文本片段的高度提供者
public struct TextHeightProvider: FragmentHeightProvider {
    public let attributedString: NSAttributedString
    public let blockQuoteDepth: Int

    public init(attributedString: NSAttributedString, blockQuoteDepth: Int) {
        self.attributedString = attributedString
        self.blockQuoteDepth = blockQuoteDepth
    }

    public func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        if blockQuoteDepth > 0 {
            return BlockQuoteTextView.estimatedHeight(
                attributedString: attributedString,
                displayedLength: displayedLength,
                blockQuoteDepth: blockQuoteDepth,
                maxWidth: maxWidth,
                theme: theme
            )
        } else {
            return MarkdownTextView.estimatedHeight(
                attributedString: attributedString,
                displayedLength: displayedLength,
                maxWidth: maxWidth,
                theme: theme
            )
        }
    }
}

// MARK: - CodeBlockHeightProvider

/// 代码块的高度提供者
public struct CodeBlockHeightProvider: FragmentHeightProvider {
    public let content: CodeBlockContent

    public init(content: CodeBlockContent) {
        self.content = content
    }

    public func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        let codeText = content.code.trimmingCharacters(in: .whitespacesAndNewlines)
        return CodeBlockView.estimatedHeight(
            codeText: codeText,
            displayedLength: displayedLength,
            maxWidth: maxWidth,
            theme: theme
        )
    }
}

// MARK: - TableHeightProvider

/// 表格的高度提供者
public struct TableHeightProvider: FragmentHeightProvider {
    public let data: TableData

    public init(data: TableData) {
        self.data = data
    }

    public func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        MarkdownTableView.estimatedHeight(
            data: data,
            displayedLength: displayedLength,
            maxWidth: maxWidth,
            theme: theme
        )
    }
}

// MARK: - FragmentViewFactory

/// 可生产 View 的 Fragment 协议
/// 方案 1：Fragment 统一携带 ViewFactory，由 Renderer 根据上下文注入 makeView 和 configure
///
/// 实现此协议的 Fragment 可直接用于 View 创建和配置，无需 ContainerView 做类型判断
public protocol FragmentViewFactory: RenderFragment {

    /// 复用标识符
    var reuseIdentifier: ReuseIdentifier { get }

    /// 预估尺寸（用于布局）
    var estimatedSize: CGSize { get }

    /// 上下文信息（indent、blockQuoteDepth 等聚合，避免平铺导致类型爆炸）
    var context: FragmentContext { get }

    /// 创建 View 的工厂方法
    func makeView() -> UIView

    /// 配置 View
    /// - Parameters:
    ///   - view: 要配置的 View（可能是新建或复用的）
    ///   - theme: 当前主题
    func configure(_ view: UIView, theme: MarkdownTheme)

    /// 按动画进度计算预估高度
    /// - Parameters:
    ///   - displayedLength: 已显示字符数（0 表示未显示）
    ///   - maxWidth: 可用宽度
    ///   - theme: 主题
    /// - Returns: 预估高度；无 heightProvider 时返回 estimatedSize.height
    func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat
}

// MARK: - Default Implementation

extension FragmentViewFactory {
    public func estimatedHeight(
        atDisplayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        estimatedSize.height
    }
}
