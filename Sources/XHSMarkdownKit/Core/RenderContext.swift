import Foundation
import UIKit

// MARK: - RenderContext

/// 渲染上下文，采用 Environment 模式（类似 SwiftUI）
/// 
/// - 不可变：每次修改返回新实例
/// - 类型安全：通过 ContextKey 协议保证
/// - 可扩展：新增 View 可以定义自己的 Key，无需修改此结构
///
/// 使用方式:
/// ```swift
/// // 创建初始 Context
/// let context = RenderContext.initial(theme: .default, maxWidth: 300)
///
/// // 读取值
/// let indent = context.indent
/// let theme = context[ThemeKey.self]
///
/// // 修改值（返回新 Context）
/// let childContext = context
///     .addingIndent(16)
///     .appendingPath("item_0")
/// ```
public struct RenderContext {
    
    // MARK: - Storage
    
    private var storage: [ObjectIdentifier: Any] = [:]
    
    // MARK: - Subscript
    
    /// 读取 Context 中的值
    public subscript<K: ContextKey>(key: K.Type) -> K.Value {
        storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }
    
    // MARK: - Mutation (返回新实例)
    
    /// 设置值，返回新 Context（不可变模式）
    public func setting<K: ContextKey>(_ key: K.Type, to value: K.Value) -> RenderContext {
        var copy = self
        copy.storage[ObjectIdentifier(key)] = value
        return copy
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    /// 带初始值的工厂方法
    public static func initial(
        theme: MarkdownTheme,
        maxWidth: CGFloat,
        stateStore: FragmentStateStore
    ) -> RenderContext {
        RenderContext()
            .setting(ThemeKey.self, to: theme)
            .setting(MaxWidthKey.self, to: maxWidth)
            .setting(StateStoreKey.self, to: stateStore)
    }
}

// MARK: - 便捷访问器

extension RenderContext {
    
    // MARK: - 读取
    
    /// 当前主题
    public var theme: MarkdownTheme { self[ThemeKey.self] }
    
    /// 最大宽度
    public var maxWidth: CGFloat { self[MaxWidthKey.self] }
    
    /// 当前缩进（累积值）
    public var indent: CGFloat { self[IndentKey.self] }
    
    /// Fragment ID 路径前缀
    public var pathPrefix: String { self[PathPrefixKey.self] }
    
    /// 列表嵌套深度
    public var listDepth: Int { self[ListDepthKey.self] }
    
    /// 引用块嵌套深度
    public var blockQuoteDepth: Int { self[BlockQuoteDepthKey.self] }
    
    /// Fragment 外部状态存储
    public var stateStore: FragmentStateStore { self[StateStoreKey.self] }
    
    // MARK: - 便捷修改
    
    /// 增加缩进
    public func addingIndent(_ delta: CGFloat) -> RenderContext {
        setting(IndentKey.self, to: indent + delta)
    }
    
    /// 追加路径组件
    public func appendingPath(_ component: String) -> RenderContext {
        let newPath = pathPrefix.isEmpty ? component : "\(pathPrefix)\(PathConstants.separator)\(component)"
        return setting(PathPrefixKey.self, to: newPath)
    }
    
    /// 进入列表（增加缩进 + 深度）
    public func enteringList() -> RenderContext {
        self.addingIndent(theme.list.nestingIndent)
            .setting(ListDepthKey.self, to: listDepth + 1)
    }
    
    /// 进入引用块（增加缩进 + 深度）
    public func enteringBlockQuote() -> RenderContext {
        self.addingIndent(theme.blockQuote.nestingIndent)
            .setting(BlockQuoteDepthKey.self, to: blockQuoteDepth + 1)
    }
    
    // MARK: - Fragment ID 生成
    
    /// 生成 Fragment ID
    /// - Parameters:
    ///   - nodeType: 节点类型名
    ///   - index: 在同类型中的索引
    /// - Returns: 稳定的 Fragment ID
    public func fragmentId(nodeType: String, index: Int) -> String {
        let component = "\(nodeType)\(PathConstants.separator)\(index)"
        return pathPrefix.isEmpty ? component : "\(pathPrefix)\(PathConstants.separator)\(component)"
    }
}
