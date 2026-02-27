//
//  FragmentContext.swift
//  XHSMarkdownKit
//

import Foundation
import UIKit

// MARK: - FragmentContextKey

/// Fragment 可声明的上下文字段
/// 新 Fragment 声明自己需要的 Key，通过 `FragmentContext.from(context, extracting: X.contextKeys)` 自动提取
public enum FragmentContextKey: String, CaseIterable, Sendable {
    case indent
    case blockQuoteDepth
    case listDepth
    case pathPrefix
    
    /// 从 RenderContext 提取该 Key 对应的值
    func extract(from context: RenderContext) -> Any {
        switch self {
        case .indent: return context.indent
        case .blockQuoteDepth: return context.blockQuoteDepth
        case .listDepth: return context.listDepth
        case .pathPrefix: return context.pathPrefix
        }
    }
    
    /// 未提取时的默认值
    var defaultValue: Any {
        switch self {
        case .indent: return CGFloat(0)
        case .blockQuoteDepth: return 0
        case .listDepth: return 0
        case .pathPrefix: return ""
        }
    }
}

// MARK: - FragmentContextRequirements

/// Fragment 声明自己需要的上下文字段，用于自动从 RenderContext 提取
/// 新 Fragment 只需实现此协议并声明 contextKeys，即可自动获取所需值
public protocol FragmentContextRequirements {
    static var contextKeys: Set<FragmentContextKey> { get }
}

// MARK: - FragmentContext

/// 渲染上下文快照（仅包含对应 Fragment 所需的字段）
///
/// 通过 `FragmentContext.from(context, extracting: TextFragment.contextKeys)` 自动从 RenderContext 提取，
/// 新 Fragment 只需声明 contextKeys，无需手动传递各字段。
public struct FragmentContext: Sendable {
    
    /// 水平缩进（用于布局）
    public let indent: CGFloat
    
    /// 引用块嵌套深度（用于绘制左侧竖线、选择 View 类型）
    public let blockQuoteDepth: Int
    
    /// 列表嵌套深度（用于 bullet 样式）
    public let listDepth: Int
    
    /// 路径前缀（调试用）
    public let pathPrefix: String
    
    public init(
        indent: CGFloat = 0,
        blockQuoteDepth: Int = 0,
        listDepth: Int = 0,
        pathPrefix: String = ""
    ) {
        self.indent = indent
        self.blockQuoteDepth = blockQuoteDepth
        self.listDepth = listDepth
        self.pathPrefix = pathPrefix
    }
}

// MARK: - 自动提取

extension FragmentContext {
    
    /// 从 RenderContext 提取指定 Keys 的值构建 FragmentContext
    /// 未在 keys 中的字段使用默认值
    ///
    /// - Example:
    ///   ```swift
    ///   let ctx = FragmentContext.from(renderContext, extracting: TextFragment.contextKeys)
    ///   ```
    public static func from(
        _ context: RenderContext,
        extracting keys: Set<FragmentContextKey> = Set(FragmentContextKey.allCases)
    ) -> FragmentContext {
        let indent = keys.contains(.indent)
            ? context.indent
            : (FragmentContextKey.indent.defaultValue as! CGFloat)
        let blockQuoteDepth = keys.contains(.blockQuoteDepth)
            ? context.blockQuoteDepth
            : (FragmentContextKey.blockQuoteDepth.defaultValue as! Int)
        let listDepth = keys.contains(.listDepth)
            ? context.listDepth
            : (FragmentContextKey.listDepth.defaultValue as! Int)
        let pathPrefix = keys.contains(.pathPrefix)
            ? context.pathPrefix
            : (FragmentContextKey.pathPrefix.defaultValue as! String)
        return FragmentContext(
            indent: indent,
            blockQuoteDepth: blockQuoteDepth,
            listDepth: listDepth,
            pathPrefix: pathPrefix
        )
    }
    
    /// 按 Fragment 声明的 contextKeys 自动提取（类型安全的便捷 API）
    public static func from<T: FragmentContextRequirements>(
        _ context: RenderContext,
        for _: T.Type = T.self
    ) -> FragmentContext {
        from(context, extracting: T.contextKeys)
    }
}
