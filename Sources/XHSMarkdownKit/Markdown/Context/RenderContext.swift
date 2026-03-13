import UIKit

public struct RenderContext {

    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: ContextKey>(key: K.Type) -> K.Value {
        storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }

    public func setting<K: ContextKey>(_ key: K.Type, to value: K.Value) -> RenderContext {
        var copy = self
        copy.storage[ObjectIdentifier(key)] = value
        return copy
    }

    // MARK: - Factory

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

    // MARK: - Convenience Accessors

    public var theme: MarkdownTheme { self[ThemeKey.self] }
    public var maxWidth: CGFloat { self[MaxWidthKey.self] }
    public var indent: CGFloat { self[IndentKey.self] }
    public var pathPrefix: String { self[PathPrefixKey.self] }
    public var listDepth: Int { self[ListDepthKey.self] }
    public var blockQuoteDepth: Int { self[BlockQuoteDepthKey.self] }
    public var stateStore: FragmentStateStore { self[StateStoreKey.self] }

    // MARK: - Convenience Mutations

    public func addingIndent(_ delta: CGFloat) -> RenderContext {
        setting(IndentKey.self, to: indent + delta)
    }

    public func appendingPath(_ component: String) -> RenderContext {
        let newPath = pathPrefix.isEmpty ? component : "\(pathPrefix)/\(component)"
        return setting(PathPrefixKey.self, to: newPath)
    }

    public func enteringList() -> RenderContext {
        let nextDepth = listDepth + 1
        let indentDelta: CGFloat = nextDepth > 1 ? theme.list.nestingIndent : 0
        return addingIndent(indentDelta)
            .setting(ListDepthKey.self, to: nextDepth)
    }

    public func enteringBlockQuote() -> RenderContext {
        setting(BlockQuoteDepthKey.self, to: blockQuoteDepth + 1)
    }

    public func fragmentId(nodeType: String, index: Int) -> String {
        let component = "\(nodeType)/\(index)"
        return pathPrefix.isEmpty ? component : "\(pathPrefix)/\(component)"
    }

    // MARK: - FragmentContext Snapshot

    public func makeFragmentContext() -> FragmentContext {
        var ctx = FragmentContext()
        ctx[IndentKey.self] = indent
        ctx[BlockQuoteDepthKey.self] = blockQuoteDepth
        ctx[ListDepthKey.self] = listDepth
        ctx[MaxWidthKey.self] = maxWidth
        if let index = storage[ObjectIdentifier(ListItemIndexKey.self)] as? Int? {
            ctx[ListItemIndexKey.self] = index
        }
        if let ordered = storage[ObjectIdentifier(IsOrderedListKey.self)] as? Bool {
            ctx[IsOrderedListKey.self] = ordered
        }
        return ctx
    }
}
