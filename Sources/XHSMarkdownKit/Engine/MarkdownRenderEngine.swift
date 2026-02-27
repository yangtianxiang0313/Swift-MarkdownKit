import Foundation
import UIKit
import XYMarkdown

// MARK: - MarkdownRenderEngine

/// Markdown 渲染引擎
/// 负责将 Markdown 文本转换为 Fragment 流
///
/// 注意：不使用单例模式，通过依赖注入配置
///
/// 使用方式:
/// ```swift
/// // 使用默认配置
/// let engine = MarkdownRenderEngine.makeDefault()
///
/// // 自定义配置
/// let engine = MarkdownRenderEngine(
///     registry: myRegistry,
///     theme: .dark,
///     configuration: .init(maxWidth: 300)
/// )
///
/// // 渲染
/// let result = engine.render("# Hello", mode: .streaming)
/// ```
public final class MarkdownRenderEngine {
    
    // MARK: - Dependencies
    
    /// 渲染器注册表
    public let registry: RendererRegistry
    
    /// 主题
    public let theme: MarkdownTheme
    
    /// 配置
    public let configuration: MarkdownConfiguration
    
    /// Fragment 外部状态存储
    public let stateStore: FragmentStateStore
    
    // MARK: - Initialization
    
    public init(
        registry: RendererRegistry,
        theme: MarkdownTheme,
        configuration: MarkdownConfiguration,
        stateStore: FragmentStateStore
    ) {
        self.registry = registry
        self.theme = theme
        self.configuration = configuration
        self.stateStore = stateStore
    }
    
    // MARK: - Render
    
    /// 渲染 Markdown 文本
    /// - Parameters:
    ///   - text: Markdown 文本
    ///   - mode: 渲染模式
    ///   - maxWidth: 可选，覆盖 configuration.maxWidth；用于高度计算时文本换行，传入 nil 则用 configuration
    /// - Returns: 渲染结果
    public func render(_ text: String, mode: RenderMode = .normal, maxWidth: CGFloat? = nil) -> MarkdownRenderResult {
        // 1. 流式模式：预处理补全未闭合标记
        let processedText: String
        if mode == .streaming {
            processedText = MarkdownPreprocessor.preclose(text)
        } else {
            processedText = text
        }
        
        // 2. 解析为 AST
        let document = Document(parsing: processedText, options: [.parseBlockDirectives])
        
        // 3. 创建初始 Context（maxWidth 影响 TextFragment 高度计算，必须为有限值才能正确换行）
        let effectiveMaxWidth = maxWidth ?? configuration.maxWidth
        let context = RenderContext.initial(
            theme: theme,
            maxWidth: effectiveMaxWidth,
            stateStore: stateStore
        )
        
        // 4. 递归渲染
        let fragments = renderNode(document, context: context)
        
        // 5. 优化 Fragment（合并相邻 TextFragment 等）
        let optimized = FragmentOptimizer.optimize(fragments)
        
        #if DEBUG
        // 调试输出
        print("=== Rendered \(optimized.count) fragments ===")
        for (index, fragment) in optimized.enumerated() {
            if let textFragment = fragment as? TextFragment {
                let text = textFragment.attributedString.string
                let preview = text.prefix(50).replacingOccurrences(of: "\n", with: "\\n")
                print("[\(index)] TextFragment id=\(textFragment.fragmentId) text=\"\(preview)\"")
            } else if let viewFragment = fragment as? ViewFragment {
                print("[\(index)] ViewFragment id=\(viewFragment.fragmentId) type=\(viewFragment.nodeType)")
            } else {
                print("[\(index)] \(type(of: fragment)) id=\(fragment.fragmentId)")
            }
        }
        print("=== End fragments ===")
        #endif
        
        return MarkdownRenderResult(
            fragments: optimized,
            sourceText: text,
            mode: mode
        )
    }
    
    // MARK: - Internal
    
    /// 递归渲染节点（核心方法）
    private func renderNode(_ node: Markup, context: RenderContext) -> [RenderFragment] {
        let nodeType = MarkdownNodeType.from(node)
        let renderer = registry.renderer(for: nodeType)
        
        // 创建子节点渲染器
        let childRenderer = ChildRenderer { [weak self] childNode, childContext in
            self?.renderNode(childNode, context: childContext) ?? []
        }
        
        return renderer.render(
            node: node,
            context: context,
            childRenderer: childRenderer
        )
    }
    
    // MARK: - Factory
    
    /// 创建使用默认配置的引擎
    public static func makeDefault(
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default,
        stateStore: FragmentStateStore = FragmentStateStore()
    ) -> MarkdownRenderEngine {
        MarkdownRenderEngine(
            registry: .makeDefault(),
            theme: theme,
            configuration: configuration,
            stateStore: stateStore
        )
    }
}

// MARK: - FragmentOptimizer

/// Fragment 优化器
public enum FragmentOptimizer {
    
    /// 优化 Fragment 数组
    /// - 移除空的 Fragment
    /// - 注意：不合并不同块的 TextFragment，因为每个块应该独立显示
    public static func optimize(_ fragments: [RenderFragment]) -> [RenderFragment] {
        // 只过滤空的 fragment，不合并！每个块级元素应该保持独立
        return fragments.filter { fragment in
            if let textFragment = fragment as? TextFragment {
                return !textFragment.isEmpty
            }
            return true
        }
    }
}
