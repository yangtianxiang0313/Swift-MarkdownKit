import UIKit

/// 内联节点渲染器 - 使用注册机制分发渲染任务
public enum InlineRenderer {

    // MARK: - 默认注册表

    /// 全局默认注册表
    private static var _defaultRegistry: InlineRendererRegistry = .makeDefault()

    /// 获取默认注册表
    public static var defaultRegistry: InlineRendererRegistry { _defaultRegistry }

    /// 设置新的默认注册表
    public static func setDefaultRegistry(_ registry: InlineRendererRegistry) {
        _defaultRegistry = registry
    }

    // MARK: - Public API

    /// 渲染一组内联节点（使用默认注册表）
    public static func render(_ nodes: [MarkdownNode], context: RenderContext) -> NSAttributedString {
        render(nodes, context: context, registry: defaultRegistry)
    }

    /// 使用指定注册表渲染一组内联节点
    public static func render(
        _ nodes: [MarkdownNode],
        context: RenderContext,
        registry: InlineRendererRegistry
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 创建子节点渲染器闭包（用于递归渲染嵌套节点）
        var childRenderer: InlineChildRenderer!
        childRenderer = InlineChildRenderer { children, ctx in
            render(children, context: ctx, registry: registry)
        }

        for node in nodes {
            if let rendered = registry.render(node: node, context: context, childRenderer: childRenderer) {
                result.append(rendered)
            }
        }

        return result
    }
}
