import Foundation
import UIKit
import XYMarkdown

// MARK: - NodeRenderer Protocol

/// 节点渲染器协议（核心扩展点）
///
/// 每个渲染器负责将一种类型的 Markdown 节点转换为 Fragment 数组。
/// 渲染器是无状态的，所有信息通过 RenderContext 传递。
///
/// 使用方式:
/// ```swift
/// struct MyCodeBlockRenderer: NodeRenderer {
///     func render(
///         node: Markup,
///         context: RenderContext,
///         childRenderer: ChildRenderer
///     ) -> [RenderFragment] {
///         guard let codeBlock = node as? CodeBlock else { return [] }
///         
///         return [
///             ViewFragment.typed(
///                 fragmentId: context.fragmentId(nodeType: "codeBlock", index: 0),
///                 nodeType: .codeBlock,
///                 reuseIdentifier: "CodeBlockView",
///                 content: codeBlock.code,
///                 makeView: { MyCodeBlockView() },
///                 configure: { view, code in view.setCode(code) }
///             )
///         ]
///     }
/// }
/// ```
public protocol NodeRenderer {
    
    /// 渲染节点，返回 Fragment 数组
    /// - Parameters:
    ///   - node: 要渲染的 Markup 节点
    ///   - context: 渲染上下文（包含主题、缩进等信息）
    ///   - childRenderer: 子节点渲染器（用于递归渲染子节点）
    /// - Returns: Fragment 数组
    func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment]
}

// MARK: - ChildRenderer

/// 子节点渲染器
/// 提供递归渲染子节点的能力
public struct ChildRenderer {
    
    private let renderFunction: (Markup, RenderContext) -> [RenderFragment]
    
    internal init(render: @escaping (Markup, RenderContext) -> [RenderFragment]) {
        self.renderFunction = render
    }
    
    /// 渲染单个子节点
    public func render(_ node: Markup, context: RenderContext) -> [RenderFragment] {
        renderFunction(node, context)
    }
    
    /// 渲染所有子节点
    public func renderChildren(of node: Markup, context: RenderContext) -> [RenderFragment] {
        node.children.flatMap { render($0, context: context) }
    }
    
    /// 渲染子节点，每个子节点带独立的路径
    public func renderChildrenWithPath(
        of node: Markup,
        context: RenderContext,
        pathPrefix: String
    ) -> [RenderFragment] {
        node.children.enumerated().flatMap { index, child in
            let childContext = context.appendingPath("\(pathPrefix)_\(index)")
            return render(child, context: childContext)
        }
    }
}

// MARK: - ClosureRenderer

/// 闭包包装的渲染器
/// 方便快速定义简单的渲染逻辑
public struct ClosureRenderer: NodeRenderer {
    
    private let closure: (Markup, RenderContext, ChildRenderer) -> [RenderFragment]
    
    public init(
        render: @escaping (Markup, RenderContext, ChildRenderer) -> [RenderFragment]
    ) {
        self.closure = render
    }
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        closure(node, context, childRenderer)
    }
}

// MARK: - FallbackRenderer

/// 回退渲染器
/// 当没有找到匹配的渲染器时使用
public struct FallbackRenderer: NodeRenderer {
    
    public init() {}
    
    public func render(
        node: Markup,
        context: RenderContext,
        childRenderer: ChildRenderer
    ) -> [RenderFragment] {
        // 尝试渲染子节点
        childRenderer.renderChildren(of: node, context: context)
    }
}
