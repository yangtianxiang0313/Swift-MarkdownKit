//
//  MarkdownKit.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit
import XYMarkdown

// MARK: - MarkdownKit

/// XHSMarkdownKit 便捷入口
///
/// 提供静态方法简化常见用法，内部使用依赖注入的引擎。
///
/// 推荐用法（依赖注入，更灵活）:
/// ```swift
/// let engine = MarkdownRenderEngine.makeDefault(theme: .dark)
/// let result = engine.render("# Hello")
/// ```
///
/// 便捷用法（静态方法，适合简单场景）:
/// ```swift
/// let result = MarkdownKit.render("# Hello", theme: .dark)
/// ```
public enum MarkdownKit {
    
    // MARK: - 基础渲染
    
    /// 渲染 Markdown 文本
    /// - Parameters:
    ///   - markdown: Markdown 文本
    ///   - theme: 样式主题
    ///   - configuration: 渲染配置
    /// - Returns: 渲染结果
    public static func render(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) -> MarkdownRenderResult {
        let engine = MarkdownRenderEngine.makeDefault(
            theme: theme,
            configuration: configuration
        )
        return engine.render(markdown, mode: .normal)
    }
    
    /// 流式渲染 Markdown 文本
    /// - Parameters:
    ///   - markdown: Markdown 文本
    ///   - theme: 样式主题
    ///   - configuration: 渲染配置
    /// - Returns: 渲染结果
    public static func renderStreaming(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) -> MarkdownRenderResult {
        let engine = MarkdownRenderEngine.makeDefault(
            theme: theme,
            configuration: configuration
        )
        return engine.render(markdown, mode: .streaming)
    }
    
    // MARK: - 高级渲染（带 Rewriter）
    
    /// 渲染并应用 AST 改写器
    /// - Parameters:
    ///   - markdown: Markdown 文本
    ///   - theme: 样式主题
    ///   - rewriters: AST 改写器列表
    ///   - configuration: 渲染配置
    /// - Returns: 渲染结果
    public static func render(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        rewriters: [AnyMarkupRewriter] = [],
        configuration: MarkdownConfiguration = .default
    ) -> MarkdownRenderResult {
        // 1. 解析
        var document = Document(parsing: markdown, options: [.parseBlockDirectives])
        
        // 2. AST 改写
        if !rewriters.isEmpty {
            let pipeline = RewriterPipeline(rewriters: rewriters)
            document = pipeline.rewrite(document)
        }
        
        // 3. 使用新引擎渲染（engine 内部会创建 RenderContext）
        let engine = MarkdownRenderEngine.makeDefault(
            theme: theme,
            configuration: configuration
        )
        return engine.render(markdown, mode: .normal)
    }
    
    // MARK: - 蓝链渲染
    
    /// 带蓝链的渲染
    public static func render(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        richLinks: [RichLinkModel],
        configuration: MarkdownConfiguration = .default
    ) -> MarkdownRenderResult {
        let rewriter = RichLinkRewriter(richLinks: richLinks)
        return render(
            markdown,
            theme: theme,
            rewriters: [AnyMarkupRewriter(rewriter)],
            configuration: configuration
        )
    }
    
    // MARK: - 便捷方法
    
    /// 渲染为纯 NSAttributedString
    public static func attributedString(
        from markdown: String,
        theme: MarkdownTheme = .default
    ) -> NSAttributedString {
        let result = render(markdown, theme: theme)
        
        // 合并所有 TextFragment 的 attributedString
        let combined = NSMutableAttributedString()
        for fragment in result.fragments {
            if let textFrag = fragment as? TextFragment {
                combined.append(textFrag.attributedString)
            }
        }
        return combined
    }
    
    // MARK: - 缓存管理
    
    /// 清除 Document 缓存
    public static func clearCache() {
        DocumentCache.shared.removeAll()
    }
    
    /// 预热缓存
    public static func preheat(_ markdowns: [String]) {
        DispatchQueue.global(qos: .utility).async {
            for markdown in markdowns {
                _ = DocumentCache.shared.document(for: markdown)
            }
        }
    }
    
    // MARK: - 工厂方法
    
    /// 创建渲染引擎
    public static func makeEngine(
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) -> MarkdownRenderEngine {
        .makeDefault(theme: theme, configuration: configuration)
    }
    
    /// 创建容器视图
    public static func makeContainerView(
        theme: MarkdownTheme = .default,
        animationConfig: AnimationConfiguration = .default
    ) -> MarkdownContainerView {
        MarkdownContainerView(
            engine: makeEngine(theme: theme),
            animationConfig: animationConfig
        )
    }
}

// MARK: - 向后兼容

/// 渲染阶段（向后兼容）
public enum RenderPhase {
    /// 流式中
    case streaming
    /// 最终状态
    case final
}

extension MarkdownKit {
    /// 渲染（向后兼容）
    @available(*, deprecated, message: "Use render(_:theme:configuration:) instead")
    public static func renderWithState(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default,
        phase: RenderPhase = .final
    ) -> MarkdownRenderResult {
        let mode: RenderMode = phase == .streaming ? .streaming : .normal
        let engine = MarkdownRenderEngine.makeDefault(theme: theme, configuration: configuration)
        return engine.render(markdown, mode: mode)
    }
}
