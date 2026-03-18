import Foundation

extension MarkdownContract {
    public struct CanonicalRenderOptions: Sendable, Equatable {
        public var themeTokens: ThemeTokens
        public var nodeStyleSheet: NodeStyleSheet
        public var metadata: [String: Value]

        public init(
            themeTokens: ThemeTokens = ThemeTokens(),
            nodeStyleSheet: NodeStyleSheet = NodeStyleSheet(),
            metadata: [String: Value] = [:]
        ) {
            self.themeTokens = themeTokens
            self.nodeStyleSheet = nodeStyleSheet
            self.metadata = metadata
        }
    }

    public struct CanonicalRenderContext: Sendable, Equatable {
        public let path: [Int]
        public let options: CanonicalRenderOptions
        public let parentStyleTokens: [StyleToken]

        public init(
            path: [Int],
            options: CanonicalRenderOptions,
            parentStyleTokens: [StyleToken] = []
        ) {
            self.path = path
            self.options = options
            self.parentStyleTokens = parentStyleTokens
        }

        public func child(
            _ index: Int,
            parentStyleTokens: [StyleToken]? = nil
        ) -> CanonicalRenderContext {
            CanonicalRenderContext(
                path: path + [index],
                options: options,
                parentStyleTokens: parentStyleTokens ?? self.parentStyleTokens
            )
        }
    }

    public protocol CanonicalRenderer {
        func render(document: CanonicalDocument, options: CanonicalRenderOptions) throws -> RenderModel
    }

    public protocol CanonicalRenderPlugin {
        func register(into registry: CanonicalRendererRegistry)
    }

    public final class CanonicalRendererRegistry {
        public typealias BlockRenderer = (_ node: CanonicalNode, _ context: CanonicalRenderContext, _ registry: CanonicalRendererRegistry) throws -> [RenderBlock]
        public typealias InlineRenderer = (_ node: CanonicalNode, _ context: CanonicalRenderContext, _ registry: CanonicalRendererRegistry) throws -> [InlineSpan]

        private var blockRenderers: [NodeKind: BlockRenderer] = [:]
        private var inlineRenderers: [NodeKind: InlineRenderer] = [:]
        private var blockFallbackRenderer: BlockRenderer?
        private var inlineFallbackRenderer: InlineRenderer?
        private var extensionRoleResolver: ((NodeKind) -> NodeRole?)?

        public init() {}

        public func registerBlockRenderer(for kind: NodeKind, renderer: @escaping BlockRenderer) {
            blockRenderers[kind] = renderer
        }

        public func registerInlineRenderer(for kind: NodeKind, renderer: @escaping InlineRenderer) {
            inlineRenderers[kind] = renderer
        }

        public func setBlockFallbackRenderer(_ renderer: @escaping BlockRenderer) {
            blockFallbackRenderer = renderer
        }

        public func setInlineFallbackRenderer(_ renderer: @escaping InlineRenderer) {
            inlineFallbackRenderer = renderer
        }

        public func install(_ plugin: CanonicalRenderPlugin) {
            plugin.register(into: self)
        }

        public func setExtensionRoleResolver(_ resolver: @escaping (NodeKind) -> NodeRole?) {
            extensionRoleResolver = resolver
        }

        public func renderBlocks(node: CanonicalNode, context: CanonicalRenderContext) throws -> [RenderBlock] {
            if let renderer = blockRenderers[node.kind] {
                return try renderer(node, context, self)
            }

            if node.kind.isExtension, let resolveRole = extensionRoleResolver, let role = resolveRole(node.kind) {
                return try defaultExtensionBlockFallback(node: node, role: role, context: context)
            }

            if let fallback = blockFallbackRenderer {
                return try fallback(node, context, self)
            }

            return try defaultBlockFallback(node: node, context: context)
        }

        public func renderInlines(node: CanonicalNode, context: CanonicalRenderContext) throws -> [InlineSpan] {
            if let renderer = inlineRenderers[node.kind] {
                return try renderer(node, context, self)
            }

            if node.kind.isExtension, let resolveRole = extensionRoleResolver, let role = resolveRole(node.kind) {
                return try defaultExtensionInlineFallback(node: node, role: role, context: context)
            }

            if let fallback = inlineFallbackRenderer {
                return try fallback(node, context, self)
            }

            return defaultInlineFallback(node: node, context: context)
        }

        public func renderBlockChildren(of node: CanonicalNode, context: CanonicalRenderContext) throws -> [RenderBlock] {
            let parentStyleTokens = resolveStyleTokens(
                for: node,
                parentStyleTokens: context.parentStyleTokens,
                options: context.options
            )

            return try node.children.enumerated().flatMap { index, child in
                let childContext = context.child(index, parentStyleTokens: parentStyleTokens)
                return try renderBlocks(node: child, context: childContext)
            }
        }

        public func renderInlineChildren(of node: CanonicalNode, context: CanonicalRenderContext) throws -> [InlineSpan] {
            let parentStyleTokens = resolveStyleTokens(
                for: node,
                parentStyleTokens: context.parentStyleTokens,
                options: context.options
            )

            return try node.children.enumerated().flatMap { index, child in
                let childContext = context.child(index, parentStyleTokens: parentStyleTokens)
                return try renderInlines(node: child, context: childContext)
            }
        }

        public static func makeDefault(plugins: [CanonicalRenderPlugin] = [StandardCanonicalRenderPlugin()]) -> CanonicalRendererRegistry {
            let registry = CanonicalRendererRegistry()
            plugins.forEach { $0.register(into: registry) }
            registry.setBlockFallbackRenderer { node, context, reg in
                try reg.defaultBlockFallback(node: node, context: context)
            }
            registry.setInlineFallbackRenderer { node, context, reg in
                reg.defaultInlineFallback(node: node, context: context)
            }
            return registry
        }
    }

    public struct DefaultCanonicalRenderer: CanonicalRenderer, NodeSpecRegistryProviding {
        public let registry: CanonicalRendererRegistry
        public let nodeSpecRegistry: NodeSpecRegistry
        private let treeValidator: TreeValidator

        public init(
            registry: CanonicalRendererRegistry = .makeDefault(),
            nodeSpecRegistry: NodeSpecRegistry = .core()
        ) {
            self.registry = registry
            self.nodeSpecRegistry = nodeSpecRegistry
            self.treeValidator = TreeValidator(registry: nodeSpecRegistry)
            self.registry.setExtensionRoleResolver { kind in
                nodeSpecRegistry.spec(for: kind)?.role
            }
        }

        public func render(document: CanonicalDocument, options: CanonicalRenderOptions = CanonicalRenderOptions()) throws -> RenderModel {
            try document.validate()
            try treeValidator.validate(document: document)

            let context = CanonicalRenderContext(path: [], options: options)
            let blocks = try registry.renderBlocks(node: document.root, context: context)
            let assets = Self.collectAssets(from: blocks)

            return RenderModel(
                schemaVersion: MarkdownContract.schemaVersion,
                documentId: document.documentId,
                blocks: blocks,
                assets: assets,
                metadata: options.metadata
            )
        }

        private static func collectAssets(from blocks: [RenderBlock]) -> [RenderAsset] {
            var result: [RenderAsset] = []

            func walk(_ block: RenderBlock) {
                if block.kind == .image,
                   case let .string(source)? = block.metadata["source"] {
                    result.append(RenderAsset(
                        id: "asset.\(block.id)",
                        type: "image",
                        source: source,
                        metadata: [:]
                    ))
                }

                for child in block.children {
                    walk(child)
                }
            }

            for block in blocks {
                walk(block)
            }

            return result
        }
    }

    public struct StandardCanonicalRenderPlugin: CanonicalRenderPlugin {
        public init() {}

        public func register(into registry: CanonicalRendererRegistry) {
            registry.registerBlockRenderer(for: .document) { node, context, reg in
                try reg.renderBlockChildren(of: node, context: context)
            }

            registry.registerBlockRenderer(for: .paragraph) { node, context, reg in
                if reg.isStandaloneImageParagraph(node) {
                    return try reg.renderBlockChildren(of: node, context: context)
                }
                return [reg.makeBlock(
                    node: node,
                    kind: .paragraph,
                    context: context,
                    inlines: try reg.renderInlineChildren(of: node, context: context)
                )]
            }

            registry.registerBlockRenderer(for: .heading) { node, context, reg in
                [reg.makeBlock(node: node, kind: .heading, context: context, inlines: try reg.renderInlineChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .list) { node, context, reg in
                [reg.makeBlock(node: node, kind: .list, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .listItem) { node, context, reg in
                [reg.makeBlock(node: node, kind: .listItem, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .blockQuote) { node, context, reg in
                [reg.makeBlock(node: node, kind: .blockQuote, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .codeBlock) { node, context, reg in
                [reg.makeBlock(node: node, kind: .codeBlock, context: context)]
            }

            registry.registerBlockRenderer(for: .table) { node, context, reg in
                [reg.makeBlock(node: node, kind: .table, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .tableHead) { node, context, reg in
                [reg.makeBlock(node: node, kind: .tableHead, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .tableBody) { node, context, reg in
                [reg.makeBlock(node: node, kind: .tableBody, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .tableRow) { node, context, reg in
                [reg.makeBlock(node: node, kind: .tableRow, context: context, children: try reg.renderBlockChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .tableCell) { node, context, reg in
                [reg.makeBlock(node: node, kind: .tableCell, context: context, inlines: try reg.renderInlineChildren(of: node, context: context))]
            }

            registry.registerBlockRenderer(for: .thematicBreak) { node, context, reg in
                [reg.makeBlock(node: node, kind: .thematicBreak, context: context)]
            }

            registry.registerBlockRenderer(for: .image) { node, context, reg in
                [reg.makeBlock(node: node, kind: .image, context: context)]
            }

            registry.registerInlineRenderer(for: .text) { node, _, reg in
                let text: String
                if case let .string(value)? = node.attrs["text"] {
                    text = value
                } else if let raw = node.source.raw {
                    text = raw
                } else {
                    text = ""
                }

                return [InlineSpan(
                    id: node.id,
                    kind: .text,
                    text: text,
                    marks: [],
                    metadata: reg.baseMetadata(for: node)
                )]
            }

            registry.registerInlineRenderer(for: .inlineCode) { node, _, reg in
                let text: String
                if case let .string(value)? = node.attrs["code"] {
                    text = value
                } else {
                    text = node.source.raw ?? ""
                }

                return [InlineSpan(
                    id: node.id,
                    kind: .inlineCode,
                    text: text,
                    marks: [MarkToken(name: "inlineCode")],
                    metadata: reg.baseMetadata(for: node)
                )]
            }

            registry.registerInlineRenderer(for: .softBreak) { node, _, reg in
                [InlineSpan(
                    id: node.id,
                    kind: .softBreak,
                    text: "\n",
                    marks: [],
                    metadata: reg.baseMetadata(for: node)
                )]
            }

            registry.registerInlineRenderer(for: .hardBreak) { node, _, reg in
                [InlineSpan(
                    id: node.id,
                    kind: .hardBreak,
                    text: "\n",
                    marks: [],
                    metadata: reg.baseMetadata(for: node)
                )]
            }

            registry.registerInlineRenderer(for: .link) { node, context, reg in
                let markValue: Value
                if node.attrs.isEmpty {
                    markValue = .null
                } else {
                    markValue = .object(node.attrs)
                }

                let children = try reg.renderInlineChildren(of: node, context: context)
                return reg.appendMark(name: "link", value: markValue, to: children)
            }

            registry.registerInlineRenderer(for: .emphasis) { node, context, reg in
                let children = try reg.renderInlineChildren(of: node, context: context)
                return reg.appendMark(name: "emphasis", value: nil, to: children)
            }

            registry.registerInlineRenderer(for: .strong) { node, context, reg in
                let children = try reg.renderInlineChildren(of: node, context: context)
                return reg.appendMark(name: "strong", value: nil, to: children)
            }

            registry.registerInlineRenderer(for: .strikethrough) { node, context, reg in
                let children = try reg.renderInlineChildren(of: node, context: context)
                return reg.appendMark(name: "strikethrough", value: nil, to: children)
            }

            registry.registerInlineRenderer(for: .image) { node, _, reg in
                [InlineSpan(
                    id: node.id,
                    kind: .image,
                    text: "",
                    marks: [],
                    metadata: reg.baseMetadata(for: node)
                )]
            }
        }
    }
}

// MARK: - Registry Helpers

private extension MarkdownContract.CanonicalRendererRegistry {
    func defaultExtensionBlockFallback(
        node: MarkdownContract.CanonicalNode,
        role: MarkdownContract.NodeRole,
        context: MarkdownContract.CanonicalRenderContext
    ) throws -> [MarkdownContract.RenderBlock] {
        if role == .blockContainer {
            return [
                makeBlock(
                    node: node,
                    kind: node.kind,
                    context: context,
                    children: try renderBlockChildren(of: node, context: context)
                )
            ]
        }

        if role == .blockLeaf {
            return [
                makeBlock(
                    node: node,
                    kind: node.kind,
                    context: context
                )
            ]
        }

        return try defaultBlockFallback(node: node, context: context)
    }

    func defaultExtensionInlineFallback(
        node: MarkdownContract.CanonicalNode,
        role: MarkdownContract.NodeRole,
        context: MarkdownContract.CanonicalRenderContext
    ) throws -> [MarkdownContract.InlineSpan] {
        if role == .inlineLeaf {
            return [
                MarkdownContract.InlineSpan(
                    id: node.id,
                    kind: node.kind,
                    text: inlineText(for: node),
                    marks: [],
                    metadata: baseMetadata(for: node)
                )
            ]
        }

        if role == .inlineContainer {
            let children = try renderInlineChildren(of: node, context: context)
            if !children.isEmpty {
                return children
            }

            return [
                MarkdownContract.InlineSpan(
                    id: node.id,
                    kind: node.kind,
                    text: inlineText(for: node),
                    marks: [],
                    metadata: baseMetadata(for: node)
                )
            ]
        }

        return defaultInlineFallback(node: node, context: context)
    }

    func defaultBlockFallback(node: MarkdownContract.CanonicalNode, context: MarkdownContract.CanonicalRenderContext) throws -> [MarkdownContract.RenderBlock] {
        let childBlocks = try renderBlockChildren(of: node, context: context)

        if !childBlocks.isEmpty {
            return [makeBlock(node: node, kind: .custom, context: context, children: childBlocks)]
        }

        let inline = defaultInlineFallback(node: node, context: context)
        if !inline.isEmpty {
            return [makeBlock(node: node, kind: .paragraph, context: context, inlines: inline)]
        }

        return [makeBlock(node: node, kind: .custom, context: context)]
    }

    func defaultInlineFallback(node: MarkdownContract.CanonicalNode, context: MarkdownContract.CanonicalRenderContext) -> [MarkdownContract.InlineSpan] {
        [MarkdownContract.InlineSpan(
            id: node.id,
            kind: .custom,
            text: inlineText(for: node),
            marks: [],
            metadata: baseMetadata(for: node)
        )]
    }

    func makeBlock(
        node: MarkdownContract.CanonicalNode,
        kind: MarkdownContract.BlockKind,
        context: MarkdownContract.CanonicalRenderContext,
        inlines: [MarkdownContract.InlineSpan] = [],
        children: [MarkdownContract.RenderBlock] = []
    ) -> MarkdownContract.RenderBlock {
        var metadata = baseMetadata(for: node)

        if case let .string(source)? = node.attrs["source"] {
            metadata["source"] = .string(source)
        }

        return MarkdownContract.RenderBlock(
            id: node.id,
            kind: kind,
            inlines: inlines,
            children: children,
            styleTokens: resolveStyleTokens(
                for: node,
                parentStyleTokens: context.parentStyleTokens,
                options: context.options
            ),
            layoutHints: .init(),
            metadata: metadata
        )
    }

    func appendMark(
        name: String,
        value: MarkdownContract.Value?,
        to spans: [MarkdownContract.InlineSpan]
    ) -> [MarkdownContract.InlineSpan] {
        spans.map { span in
            var updated = span
            updated.marks.append(.init(name: name, value: value))
            return updated
        }
    }

    func resolveStyleTokens(
        for node: MarkdownContract.CanonicalNode,
        parentStyleTokens: [MarkdownContract.StyleToken],
        options: MarkdownContract.CanonicalRenderOptions
    ) -> [MarkdownContract.StyleToken] {
        let nodeKey = node.kind.rawValue
        let customName: String?
        if case let .string(name)? = node.attrs["name"] {
            customName = name
        } else {
            customName = nil
        }

        let kindRule = options.nodeStyleSheet.byNodeKind[nodeKey]
        let customRule = customName.flatMap { options.nodeStyleSheet.byCustomElementName[$0] }

        let inherit = customRule?.inheritFromParent
            ?? kindRule?.inheritFromParent
            ?? options.nodeStyleSheet.defaultRule?.inheritFromParent
            ?? false

        var resolved: [MarkdownContract.StyleToken] = inherit ? parentStyleTokens : []

        if let defaultRule = options.nodeStyleSheet.defaultRule {
            resolved = mergeStyleTokens(
                resolved,
                with: styleTokens(
                    from: defaultRule,
                    themeTokens: options.themeTokens.values
                )
            )
        }

        if let kindRule {
            resolved = mergeStyleTokens(
                resolved,
                with: styleTokens(
                    from: kindRule,
                    themeTokens: options.themeTokens.values
                )
            )
        }

        if let customRule {
            resolved = mergeStyleTokens(
                resolved,
                with: styleTokens(
                    from: customRule,
                    themeTokens: options.themeTokens.values
                )
            )
        }

        return resolved
    }

    private func styleTokens(
        from rule: MarkdownContract.NodeStyleRule,
        themeTokens: [String: MarkdownContract.StyleValue]
    ) -> [MarkdownContract.StyleToken] {
        var result: [MarkdownContract.StyleToken] = []
        result.reserveCapacity(rule.themeTokenRefs.count + rule.styleTokens.count)

        for reference in rule.themeTokenRefs {
            guard let value = themeTokens[reference] else { continue }
            result.append(MarkdownContract.StyleToken(name: reference, value: value))
        }

        result.append(contentsOf: rule.styleTokens)
        return result
    }

    private func mergeStyleTokens(
        _ base: [MarkdownContract.StyleToken],
        with overlay: [MarkdownContract.StyleToken]
    ) -> [MarkdownContract.StyleToken] {
        guard !overlay.isEmpty else { return base }

        var result = base
        var indexByName: [String: Int] = [:]
        indexByName.reserveCapacity(result.count + overlay.count)

        for (index, token) in result.enumerated() {
            indexByName[token.name] = index
        }

        for token in overlay {
            if let index = indexByName[token.name] {
                result[index] = token
            } else {
                indexByName[token.name] = result.count
                result.append(token)
            }
        }

        return result
    }

    func baseMetadata(for node: MarkdownContract.CanonicalNode) -> [String: MarkdownContract.Value] {
        var metadata = node.metadata

        metadata["sourceKind"] = .string(node.source.sourceKind.key)

        if let raw = node.source.raw {
            metadata["sourceRaw"] = .string(raw)
        }

        if !node.attrs.isEmpty {
            metadata["attrs"] = .object(node.attrs)
        }

        if !node.additionalFields.isEmpty {
            metadata["nodeAdditional"] = .object(node.additionalFields)
        }

        return metadata
    }

    func inlineText(for node: MarkdownContract.CanonicalNode) -> String {
        if case let .string(value)? = node.attrs["text"] {
            return value
        }

        if let raw = node.source.raw {
            return raw
        }

        if case let .string(value)? = node.attrs["raw"] {
            return value
        }

        return ""
    }

    func isStandaloneImageParagraph(_ node: MarkdownContract.CanonicalNode) -> Bool {
        guard node.kind == .paragraph else { return false }
        guard !node.children.isEmpty else { return false }
        return node.children.allSatisfy { $0.kind == .image }
    }
}
