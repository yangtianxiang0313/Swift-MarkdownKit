import Foundation
import UIKit

// MARK: - InlineNodeRenderer

/// 内联节点渲染协议 - 让节点自描述渲染逻辑
public protocol InlineNodeRenderer {
    /// 渲染单个内联节点
    /// - Parameters:
    ///   - node: 要渲染的内联节点
    ///   - context: 渲染上下文
    ///   - childRenderer: 用于渲染子节点的闭包（处理嵌套内联节点）
    /// - Returns: 渲染后的 NSAttributedString，返回 nil 表示该 Renderer 不处理此节点
    func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString?
}

// MARK: - InlineChildRenderer

/// 用于渲染嵌套内联节点的子节点渲染器
public struct InlineChildRenderer {
    private let renderFunction: ([MarkdownNode], RenderContext) -> NSAttributedString

    public init(render: @escaping ([MarkdownNode], RenderContext) -> NSAttributedString) {
        self.renderFunction = render
    }

    /// 渲染一组子节点
    public func render(_ nodes: [MarkdownNode], context: RenderContext) -> NSAttributedString {
        renderFunction(nodes, context)
    }

    /// 渲染单个子节点
    public func render(_ node: MarkdownNode, context: RenderContext) -> NSAttributedString {
        render([node], context: context)
    }
}

// MARK: - InlineRendererRegistry

/// 内联节点渲染器注册表
public final class InlineRendererRegistry {

    // MARK: - 存储结构

    /// 按节点类型存储的渲染器（用于更精确的匹配）
    private var renderersByNodeType: [FragmentNodeType: InlineNodeRenderer] = [:]

    /// 按匹配规则存储的渲染器（按注册顺序匹配）
    private var matcherRenderers: [MatcherRenderer] = []

    /// 默认渲染器列表（按注册顺序尝试）
    private var defaultRenderers: [InlineNodeRenderer] = []

    /// 回退渲染器
    private var fallbackRenderer: InlineNodeRenderer?

    // MARK: - Registration

    public init() {}

    public typealias Matcher = (MarkdownNode) -> Bool

    private struct MatcherRenderer {
        let renderer: InlineNodeRenderer
        let matches: Matcher
    }

    /// 为特定 FragmentNodeType 注册渲染器
    public func register(_ renderer: InlineNodeRenderer, for nodeType: FragmentNodeType) {
        renderersByNodeType[nodeType] = renderer
    }

    /// 为匹配条件注册渲染器（按注册顺序生效）
    public func register(_ renderer: InlineNodeRenderer, matching matcher: @escaping Matcher) {
        matcherRenderers.append(MatcherRenderer(renderer: renderer, matches: matcher))
    }

    /// 注册默认渲染器（用于所有未被特定匹配的节点）
    public func registerDefault(_ renderer: InlineNodeRenderer) {
        defaultRenderers.append(renderer)
    }

    /// 设置回退渲染器（当所有匹配都失败时使用）
    public func setFallback(_ renderer: InlineNodeRenderer) {
        fallbackRenderer = renderer
    }

    // MARK: - Rendering

    /// 渲染单个节点
    /// - Returns: 渲染结果，nil 表示无渲染器可处理此节点
    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        // 1. 尝试按 FragmentNodeType 精确匹配
        if let renderer = renderersByNodeType[node.nodeType] {
            if let result = renderer.render(node: node, context: context, childRenderer: childRenderer) {
                return result
            }
        }

        // 2. 尝试按 matcher 规则匹配
        for registration in matcherRenderers where registration.matches(node) {
            if let result = registration.renderer.render(node: node, context: context, childRenderer: childRenderer) {
                return result
            }
        }

        // 3. 尝试默认渲染器列表（按顺序尝试，直到有渲染器返回非 nil）
        for renderer in defaultRenderers {
            if let result = renderer.render(node: node, context: context, childRenderer: childRenderer) {
                return result
            }
        }

        // 4. 使用回退渲染器
        if let fallback = fallbackRenderer {
            return fallback.render(node: node, context: context, childRenderer: childRenderer)
        }

        return nil
    }

    // MARK: - Factory

    /// 创建默认的内联渲染器注册表
    public static func makeDefault() -> InlineRendererRegistry {
        let registry = InlineRendererRegistry()
        registry.registerDefaultRenderers()
        return registry
    }

    private func registerDefaultRenderers() {
        register(TextInlineRenderer(), matching: { $0 is TextNode })
        register(InlineCodeRenderer(), matching: { $0 is InlineCodeNode })
        register(StrongInlineRenderer(), matching: { $0 is StrongNode })
        register(EmphasisInlineRenderer(), matching: { $0 is EmphasisNode })
        register(LinkInlineRenderer(), matching: { $0 is LinkNode })
        register(StrikethroughInlineRenderer(), matching: { $0 is StrikethroughNode })
        register(SoftBreakInlineRenderer(), matching: { $0 is SoftBreakNode })
        register(LineBreakInlineRenderer(), matching: { $0 is LineBreakNode })
        setFallback(ChildrenOnlyInlineRenderer())
    }
}

// MARK: - Default Inline Renderers

/// 文本节点渲染器
public struct TextInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard let text = node as? TextNode else { return nil }
        return NSAttributedString(string: text.text, attributes: bodyAttributes(theme: context.theme))
    }
}

/// 内联代码渲染器
public struct InlineCodeRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard let code = node as? InlineCodeNode else { return nil }
        var attrs = bodyAttributes(theme: context.theme)
        attrs[.font] = context.theme.code.font
        attrs[.foregroundColor] = context.theme.code.inlineColor
        if let bg = context.theme.code.inlineBackgroundColor {
            attrs[.backgroundColor] = bg
        }
        return NSAttributedString(string: code.code, attributes: attrs)
    }
}

/// 粗体节点渲染器
public struct StrongInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard node is StrongNode else { return nil }
        let inner = childRenderer.render(node.children, context: context)
        let mutable = NSMutableAttributedString(attributedString: inner)
        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            if let font = value as? UIFont {
                mutable.addAttribute(.font, value: font.bold, range: range)
            }
        }
        return mutable
    }
}

/// 强调节点渲染器
public struct EmphasisInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard node is EmphasisNode else { return nil }
        let inner = childRenderer.render(node.children, context: context)
        let mutable = NSMutableAttributedString(attributedString: inner)

        switch context.theme.emphasis.type {
        case .italic:
            applyItalic(to: mutable)
        case .highlight:
            mutable.addAttribute(
                .backgroundColor,
                value: context.theme.emphasis.highlightColor,
                range: NSRange(location: 0, length: mutable.length)
            )
        case .both:
            applyItalic(to: mutable)
            mutable.addAttribute(
                .backgroundColor,
                value: context.theme.emphasis.highlightColor,
                range: NSRange(location: 0, length: mutable.length)
            )
        }
        return mutable
    }

    private func applyItalic(to mutable: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if let font = value as? UIFont {
                let italicFont = font.italic
                if italicFont.isItalic {
                    mutable.addAttribute(.font, value: italicFont, range: range)
                } else {
                    mutable.addAttribute(.obliqueness, value: NSNumber(value: 0.2), range: range)
                }
            }
        }
    }
}

/// 链接节点渲染器
public struct LinkInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard let link = node as? LinkNode else { return nil }
        let inner = childRenderer.render(node.children, context: context)
        let mutable = NSMutableAttributedString(attributedString: inner)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: context.theme.link.color, range: range)
        if let dest = link.destination, let url = URL(string: dest) {
            mutable.addAttribute(.link, value: url, range: range)
        }
        if context.theme.link.underlineStyle != [] {
            mutable.addAttribute(.underlineStyle, value: context.theme.link.underlineStyle.rawValue, range: range)
        }
        return mutable
    }
}

/// 删除线节点渲染器
public struct StrikethroughInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard node is StrikethroughNode else { return nil }
        let inner = childRenderer.render(node.children, context: context)
        let mutable = NSMutableAttributedString(attributedString: inner)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.strikethroughStyle, value: context.theme.strikethrough.style.rawValue, range: range)
        if let color = context.theme.strikethrough.color {
            mutable.addAttribute(.strikethroughColor, value: color, range: range)
        }
        return mutable
    }
}

/// 软换行渲染器
public struct SoftBreakInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard node is SoftBreakNode else { return nil }
        return NSAttributedString(string: " ", attributes: bodyAttributes(theme: context.theme))
    }
}

/// 硬换行渲染器
public struct LineBreakInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        guard node is LineBreakNode else { return nil }
        return NSAttributedString(string: "\n", attributes: bodyAttributes(theme: context.theme))
    }
}

/// 回退渲染器 - 只渲染子节点
public struct ChildrenOnlyInlineRenderer: InlineNodeRenderer {
    public init() {}

    public func render(
        node: MarkdownNode,
        context: RenderContext,
        childRenderer: InlineChildRenderer
    ) -> NSAttributedString? {
        return childRenderer.render(node.children, context: context)
    }
}

// MARK: - Helper

/// 生成正文属性
private func bodyAttributes(theme: MarkdownTheme) -> [NSAttributedString.Key: Any] {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = theme.body.lineHeight
    paragraphStyle.maximumLineHeight = theme.body.lineHeight

    return [
        .font: theme.body.font,
        .foregroundColor: theme.body.color,
        .paragraphStyle: paragraphStyle,
        .kern: theme.body.letterSpacing,
        .baselineOffset: (theme.body.lineHeight - theme.body.font.lineHeight) / 4
    ]
}
