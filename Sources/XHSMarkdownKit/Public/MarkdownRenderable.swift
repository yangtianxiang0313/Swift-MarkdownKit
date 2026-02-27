//
//  MarkdownRenderable.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

/// 让任何 View 具备 Markdown 渲染能力
///
/// 务实的好处：
/// 1. 消除每个使用方的样板代码（parse → render → 赋值）
/// 2. 统一入口，便于后续加入渲染缓存、性能监控等中间逻辑
/// 3. 与 MarkdownConfiguration 天然配合
public protocol MarkdownRenderable: AnyObject {
    /// 使用 Markdown 文本更新 View 内容
    func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme,
        configuration: MarkdownConfiguration
    )
    
    /// 使用已有的渲染结果更新 View 内容（跳过渲染，适用于缓存场景）
    func applyRenderResult(_ result: MarkdownRenderResult)
}

// MARK: - 默认实现

public extension MarkdownRenderable {
    /// 使用默认配置渲染
    func renderMarkdown(_ text: String, theme: MarkdownTheme = .default) {
        renderMarkdown(text, theme: theme, configuration: .default)
    }
}

// MARK: - UILabel 默认实现（纯文本场景）

extension UILabel: MarkdownRenderable {
    public func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) {
        let result = MarkdownKit.render(text, theme: theme, configuration: configuration)
        applyRenderResult(result)
    }
    
    public func applyRenderResult(_ result: MarkdownRenderResult) {
        self.numberOfLines = 0
        self.attributedText = result.attributedString
    }
}

// MARK: - UITextView 默认实现（支持链接点击）

extension UITextView: MarkdownRenderable {
    public func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) {
        let result = MarkdownKit.render(text, theme: theme, configuration: configuration)
        applyRenderResult(result)
    }
    
    public func applyRenderResult(_ result: MarkdownRenderResult) {
        self.attributedText = result.attributedString
        self.isEditable = false
        self.isScrollEnabled = false
        self.textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
        self.backgroundColor = .clear
    }
}

// MARK: - MarkdownContainerView 实现

extension MarkdownContainerView: MarkdownRenderable {
    public func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) {
        let result = MarkdownKit.render(text, theme: theme, configuration: configuration)
        applyRenderResult(result)
    }
    
    public func applyRenderResult(_ result: MarkdownRenderResult) {
        apply(result)
    }
}
