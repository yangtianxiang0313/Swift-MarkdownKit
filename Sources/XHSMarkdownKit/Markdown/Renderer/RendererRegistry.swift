import Foundation

public final class RendererRegistry {

    private var customRenderers: [FragmentNodeType: NodeRenderer] = [:]
    private var defaultRenderers: [FragmentNodeType: NodeRenderer] = [:]
    private var wildcardRenderers: [String: NodeRenderer] = [:]

    public init() {}

    // MARK: - Registration

    public func register(_ renderer: NodeRenderer, for nodeType: FragmentNodeType) {
        customRenderers[nodeType] = renderer
    }

    public func register(
        for nodeType: FragmentNodeType,
        render: @escaping (MarkdownNode, RenderContext, ChildRenderer) -> [RenderFragment]
    ) {
        customRenderers[nodeType] = ClosureRenderer(render: render)
    }

    public func registerDefault(_ renderer: NodeRenderer, for nodeType: FragmentNodeType) {
        defaultRenderers[nodeType] = renderer
    }

    public func registerWildcard(_ renderer: NodeRenderer, forPrefix prefix: String) {
        wildcardRenderers[prefix] = renderer
    }

    // MARK: - Resolution

    public func renderer(for nodeType: FragmentNodeType) -> NodeRenderer {
        if let custom = customRenderers[nodeType] { return custom }
        if let def = defaultRenderers[nodeType] { return def }

        let raw = nodeType.rawValue
        for (prefix, renderer) in wildcardRenderers {
            if raw.hasPrefix(prefix) { return renderer }
        }

        return FallbackRenderer()
    }

    // MARK: - Management

    public func removeCustomRenderer(for nodeType: FragmentNodeType) {
        customRenderers.removeValue(forKey: nodeType)
    }

    public func removeAllCustomRenderers() {
        customRenderers.removeAll()
    }

    // MARK: - Factory

    public static func makeDefault() -> RendererRegistry {
        let registry = RendererRegistry()
        registry.registerDefaultRenderers()
        return registry
    }

    private func registerDefaultRenderers() {
        registerDefault(DefaultDocumentRenderer(), for: .document)
        registerDefault(DefaultParagraphRenderer(), for: .paragraph)
        registerDefault(DefaultCodeBlockRenderer(), for: .codeBlock)
        registerDefault(DefaultBlockQuoteRenderer(), for: .blockQuote)
        registerDefault(DefaultOrderedListRenderer(), for: .orderedList)
        registerDefault(DefaultUnorderedListRenderer(), for: .unorderedList)
        registerDefault(DefaultListItemRenderer(), for: .listItem)
        registerDefault(DefaultTableRenderer(), for: .table)
        registerDefault(DefaultThematicBreakRenderer(), for: .thematicBreak)
        registerDefault(DefaultImageRenderer(), for: .image)
        registerWildcard(DefaultHeadingRenderer(), forPrefix: "heading.")
    }
}
