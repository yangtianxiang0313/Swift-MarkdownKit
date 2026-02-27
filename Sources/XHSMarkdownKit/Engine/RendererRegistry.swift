import Foundation
import UIKit
import XYMarkdown

// MARK: - RendererRegistry

/// 渲染器注册表
/// 管理节点类型与渲染器的映射关系
///
/// 注意：不使用单例模式，通过依赖注入使用
///
/// 使用方式:
/// ```swift
/// // 创建带默认渲染器的注册表
/// let registry = RendererRegistry.makeDefault()
///
/// // 注册自定义渲染器（覆盖默认）
/// registry.register(MyCodeBlockRenderer(), for: .codeBlock)
///
/// // 使用闭包注册
/// registry.register(for: .heading(level: 1)) { node, context, childRenderer in
///     // 自定义渲染逻辑
/// }
/// ```
public final class RendererRegistry {
    
    // MARK: - Storage
    
    /// 自定义渲染器（优先级高）
    private var customRenderers: [MarkdownNodeType: NodeRenderer] = [:]
    
    /// 默认渲染器
    private var defaultRenderers: [MarkdownNodeType: NodeRenderer] = [:]
    
    /// 通配渲染器（按节点类型大类匹配）
    private var wildcardRenderers: [String: NodeRenderer] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Registration
    
    /// 注册自定义渲染器
    public func register(_ renderer: NodeRenderer, for nodeType: MarkdownNodeType) {
        customRenderers[nodeType] = renderer
    }
    
    /// 使用闭包注册自定义渲染器
    public func register(
        for nodeType: MarkdownNodeType,
        render: @escaping (Markup, RenderContext, ChildRenderer) -> [RenderFragment]
    ) {
        customRenderers[nodeType] = ClosureRenderer(render: render)
    }
    
    /// 注册默认渲染器（内部使用）
    internal func registerDefault(_ renderer: NodeRenderer, for nodeType: MarkdownNodeType) {
        defaultRenderers[nodeType] = renderer
    }
    
    /// 注册通配渲染器（如所有 heading 级别共用一个渲染器）
    public func registerWildcard(_ renderer: NodeRenderer, forCategory category: RendererCategory) {
        wildcardRenderers[category.rawValue] = renderer
    }
    
    // MARK: - Resolution
    
    /// 获取渲染器
    /// 优先级：自定义 > 默认 > 通配 > 回退
    public func renderer(for nodeType: MarkdownNodeType) -> NodeRenderer {
        // 1. 自定义渲染器
        if let custom = customRenderers[nodeType] {
            return custom
        }
        
        // 2. 默认渲染器
        if let defaultRenderer = defaultRenderers[nodeType] {
            return defaultRenderer
        }
        
        // 3. 通配渲染器
        if let category = nodeType.category,
           let wildcard = wildcardRenderers[category.rawValue] {
            return wildcard
        }
        
        // 4. 回退渲染器
        return FallbackRenderer()
    }
    
    /// 获取默认渲染器（用于在自定义渲染器中"继承"默认行为）
    public func defaultRenderer(for nodeType: MarkdownNodeType) -> NodeRenderer? {
        defaultRenderers[nodeType]
    }
    
    // MARK: - Reset
    
    /// 移除自定义渲染器
    public func removeCustomRenderer(for nodeType: MarkdownNodeType) {
        customRenderers.removeValue(forKey: nodeType)
    }
    
    /// 移除所有自定义渲染器
    public func removeAllCustomRenderers() {
        customRenderers.removeAll()
    }
    
    // MARK: - Factory
    
    /// 创建带默认渲染器的注册表
    public static func makeDefault() -> RendererRegistry {
        let registry = RendererRegistry()
        registry.registerDefaultRenderers()
        return registry
    }
    
    /// 注册所有默认渲染器
    private func registerDefaultRenderers() {
        // Document（根节点）
        registerDefault(DefaultDocumentRenderer(), for: .document)
        
        // 块级节点
        registerDefault(DefaultParagraphRenderer(), for: .paragraph)
        registerDefault(DefaultCodeBlockRenderer(), for: .codeBlock)
        registerDefault(DefaultBlockQuoteRenderer(), for: .blockQuote)
        registerDefault(DefaultOrderedListRenderer(), for: .orderedList)
        registerDefault(DefaultUnorderedListRenderer(), for: .unorderedList)
        registerDefault(DefaultListItemRenderer(), for: .listItem)
        registerDefault(DefaultTableRenderer(), for: .table)
        registerDefault(DefaultThematicBreakRenderer(), for: .thematicBreak)
        registerDefault(DefaultImageRenderer(), for: .image)
        
        // Heading 使用通配渲染器
        registerWildcard(DefaultHeadingRenderer(), forCategory: .heading)
        
        // 行内节点（一般不需要单独渲染器，由 InlineRenderer 处理）
    }
}

// MARK: - MarkdownNodeType Category

extension MarkdownNodeType {
    
    /// 节点类型大类（用于通配匹配）
    var category: RendererCategory? {
        switch self {
        case .heading:
            return .heading
        case .orderedList, .unorderedList:
            return .list
        case .taskListItem:
            return .taskListItem
        default:
            return nil
        }
    }
}
