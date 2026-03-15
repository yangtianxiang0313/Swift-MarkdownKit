import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

extension MarkdownContract {
    public protocol UIKitNodeRenderPlugin {
        func register(into adapter: RenderModelUIKitAdapter)
    }

    public struct MergeTextSegment {
        public var sourceBlockID: String
        public var kind: String
        public var attributedText: NSAttributedString
        public var spacingAfter: CGFloat
        public var metadata: [String: Value]
        public var forceMergeBreakAfter: Bool

        public init(
            sourceBlockID: String,
            kind: String,
            attributedText: NSAttributedString,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:],
            forceMergeBreakAfter: Bool = false
        ) {
            self.sourceBlockID = sourceBlockID
            self.kind = kind
            self.attributedText = attributedText
            if spacingAfter.isFinite {
                self.spacingAfter = max(0, spacingAfter)
            } else {
                self.spacingAfter = 0
            }
            self.metadata = metadata
            self.forceMergeBreakAfter = forceMergeBreakAfter
        }
    }

    public struct StandaloneNodeDescriptor {
        public var id: String
        public var kind: String
        public var component: any SceneComponent
        public var spacingAfter: CGFloat
        public var metadata: [String: Value]

        public init(
            id: String,
            kind: String,
            component: any SceneComponent,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.component = component
            if spacingAfter.isFinite {
                self.spacingAfter = max(0, spacingAfter)
            } else {
                self.spacingAfter = 0
            }
            self.metadata = metadata
        }
    }

    public enum BlockMappingResult {
        case mergeSegment(MergeTextSegment)
        case standalone(StandaloneNodeDescriptor)

        fileprivate var spacingAfter: CGFloat {
            switch self {
            case let .mergeSegment(segment):
                return segment.spacingAfter
            case let .standalone(standalone):
                return standalone.spacingAfter
            }
        }

        fileprivate func withSpacingAfter(_ spacingAfter: CGFloat) -> BlockMappingResult {
            let resolvedSpacing: CGFloat
            if spacingAfter.isFinite {
                resolvedSpacing = max(0, spacingAfter)
            } else {
                resolvedSpacing = 0
            }
            switch self {
            case var .mergeSegment(segment):
                segment.spacingAfter = resolvedSpacing
                return .mergeSegment(segment)
            case var .standalone(standalone):
                standalone.spacingAfter = resolvedSpacing
                return .standalone(standalone)
            }
        }

        fileprivate func addingSpacingAfter(_ delta: CGFloat) -> BlockMappingResult {
            withSpacingAfter(spacingAfter + max(0, delta))
        }
    }

    public protocol SceneMergePolicy {
        func shouldMerge(previous: MergeTextSegment, next: MergeTextSegment) -> Bool
        func shouldBreak(after segment: MergeTextSegment) -> Bool
        func mergedNodeID(for segments: [MergeTextSegment]) -> String
        func mergedNodeKind(for segments: [MergeTextSegment]) -> String
        func mergedNodeSpacingAfter(for segments: [MergeTextSegment]) -> CGFloat
        func mergedNodeMetadata(for segments: [MergeTextSegment]) -> [String: Value]
    }

    public struct FirstBlockAnchoredMergePolicy: SceneMergePolicy {
        public init() {}

        public func shouldMerge(previous: MergeTextSegment, next: MergeTextSegment) -> Bool {
            !shouldBreak(after: previous)
        }

        public func shouldBreak(after segment: MergeTextSegment) -> Bool {
            segment.forceMergeBreakAfter
        }

        public func mergedNodeID(for segments: [MergeTextSegment]) -> String {
            segments.first?.sourceBlockID ?? "merged.text"
        }

        public func mergedNodeKind(for segments: [MergeTextSegment]) -> String {
            "mergedText"
        }

        public func mergedNodeSpacingAfter(for segments: [MergeTextSegment]) -> CGFloat {
            segments.last?.spacingAfter ?? 0
        }

        public func mergedNodeMetadata(for segments: [MergeTextSegment]) -> [String: Value] {
            var metadata: [String: Value] = [
                "memberBlockIDs": .array(segments.map { .string($0.sourceBlockID) }),
                "memberKinds": .array(segments.map { .string($0.kind) })
            ]

            for segment in segments {
                for (key, value) in segment.metadata {
                    metadata[key] = value
                }
            }
            return metadata
        }
    }

    public final class BlockMapperChain {
        public typealias Mapper = (
            _ block: RenderBlock,
            _ context: RenderModelUIKitAdapter.Context,
            _ adapter: RenderModelUIKitAdapter
        ) throws -> [BlockMappingResult]?

        private var mappers: [Mapper]

        public init(mappers: [Mapper] = []) {
            self.mappers = mappers
        }

        public func prepend(_ mapper: @escaping Mapper) {
            mappers.insert(mapper, at: 0)
        }

        public func append(_ mapper: @escaping Mapper) {
            mappers.append(mapper)
        }

        public var isEmpty: Bool { mappers.isEmpty }

        fileprivate func map(
            block: RenderBlock,
            context: RenderModelUIKitAdapter.Context,
            adapter: RenderModelUIKitAdapter
        ) throws -> [BlockMappingResult]? {
            for mapper in mappers {
                if let mapped = try mapper(block, context, adapter) {
                    return mapped
                }
            }
            return nil
        }
    }

    public final class RenderModelUIKitAdapter {
        public struct Context {
            public var theme: MarkdownTheme
            public var maxWidth: CGFloat
            public var indent: CGFloat
            public var listDepth: Int
            public var isOrderedList: Bool
            public var listItemIndex: Int?
            public var blockQuoteDepth: Int

            public init(
                theme: MarkdownTheme,
                maxWidth: CGFloat,
                indent: CGFloat = 0,
                listDepth: Int = 0,
                isOrderedList: Bool = false,
                listItemIndex: Int? = nil,
                blockQuoteDepth: Int = 0
            ) {
                self.theme = theme
                self.maxWidth = maxWidth
                self.indent = indent
                self.listDepth = listDepth
                self.isOrderedList = isOrderedList
                self.listItemIndex = listItemIndex
                self.blockQuoteDepth = blockQuoteDepth
            }

            func applying(layoutHints: LayoutHints) -> Context {
                var next = self
                if let indent = layoutHints.indent {
                    next.indent += CGFloat(indent)
                }
                if let maxWidth = layoutHints.maxWidth {
                    next.maxWidth = min(next.maxWidth, CGFloat(maxWidth))
                }
                return next
            }

            func enteringList(ordered: Bool) -> Context {
                var next = self
                let nextDepth = listDepth + 1
                if nextDepth > 1 {
                    next.indent += theme.list.nestingIndent
                }
                next.listDepth = nextDepth
                next.isOrderedList = ordered
                next.listItemIndex = nil
                return next
            }

            func withListItemIndex(_ index: Int?) -> Context {
                var next = self
                next.listItemIndex = index
                return next
            }

            func enteringBlockQuote() -> Context {
                var next = self
                next.blockQuoteDepth += 1
                return next
            }
        }

        public typealias BlockMapper = (
            _ block: RenderBlock,
            _ context: Context,
            _ adapter: RenderModelUIKitAdapter
        ) throws -> [BlockMappingResult]

        public typealias InlineRenderer = (
            _ span: InlineSpan,
            _ block: RenderBlock,
            _ context: Context,
            _ adapter: RenderModelUIKitAdapter
        ) -> NSAttributedString?

        public typealias CustomMarkAttributeResolver = (
            _ mark: MarkToken,
            _ attributes: inout [NSAttributedString.Key: Any],
            _ block: RenderBlock,
            _ context: Context
        ) -> Void

        public var customMarkAttributeResolver: CustomMarkAttributeResolver?

        public var mergePolicy: any SceneMergePolicy
        public var blockMapperChain: BlockMapperChain

        private var inlineRenderers: [String: InlineRenderer] = [:]

        public init(
            mergePolicy: any SceneMergePolicy,
            blockMapperChain: BlockMapperChain,
            plugins: [UIKitNodeRenderPlugin] = []
        ) {
            self.mergePolicy = mergePolicy
            self.blockMapperChain = blockMapperChain
            plugins.forEach { $0.register(into: self) }
        }

        public static func makeDefaultBlockMapperChain() -> BlockMapperChain {
            let chain = BlockMapperChain()
            chain.append { block, context, adapter in
                try adapter.mapCoreBlock(block, context: context)
            }
            return chain
        }

        public func registerBlockMapper(for kind: BlockKind, mapper: @escaping BlockMapper) {
            registerBlockMapper(forKey: key(for: kind), mapper: mapper)
        }

        public func registerBlockMapper(forKey key: String, mapper: @escaping BlockMapper) {
            blockMapperChain.prepend { block, context, adapter in
                guard adapter.candidateKeys(for: block).contains(key) else { return nil }
                return try mapper(block, context, adapter)
            }
        }

        public func registerBlockMapper(forExtension name: String, mapper: @escaping BlockMapper) {
            registerBlockMapper(forKey: "ext:\(name)", mapper: mapper)
        }

        public func registerInlineRenderer(for kind: InlineKind, renderer: @escaping InlineRenderer) {
            inlineRenderers[key(for: kind)] = renderer
        }

        public func registerInlineRenderer(forKey key: String, renderer: @escaping InlineRenderer) {
            inlineRenderers[key] = renderer
        }

        public func registerInlineRenderer(forExtension name: String, renderer: @escaping InlineRenderer) {
            inlineRenderers["ext:\(name)"] = renderer
        }

        public func removeInlineRenderer(for kind: InlineKind) {
            inlineRenderers.removeValue(forKey: key(for: kind))
        }

        public func removeInlineRenderer(forKey key: String) {
            inlineRenderers.removeValue(forKey: key)
        }

        public func removeInlineRenderer(forExtension name: String) {
            inlineRenderers.removeValue(forKey: "ext:\(name)")
        }

        public func render(
            model: RenderModel,
            theme: MarkdownTheme,
            maxWidth: CGFloat
        ) throws -> RenderScene {
            guard !blockMapperChain.isEmpty else {
                throw MarkdownContract.ModelError(
                    code: .requiredFieldMissing,
                    message: "BlockMapperChain is required",
                    path: "RenderModelUIKitAdapter.blockMapperChain"
                )
            }

            let context = Context(theme: theme, maxWidth: maxWidth)
            let mapped = try mapBlocks(model.blocks, context: context)
            let nodes = merge(mappedResults: mapped, theme: theme)
            return RenderScene(documentId: model.documentId, nodes: nodes, metadata: model.metadata)
        }

        public func makeMergeTextSegment(
            sourceBlockID: String,
            kind: String,
            attributedText: NSAttributedString,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:],
            forceMergeBreakAfter: Bool = false
        ) -> MergeTextSegment {
            MergeTextSegment(
                sourceBlockID: sourceBlockID,
                kind: kind,
                attributedText: attributedText,
                spacingAfter: spacingAfter,
                metadata: metadata,
                forceMergeBreakAfter: forceMergeBreakAfter
            )
        }

        public func makeStandaloneNode(
            id: String,
            kind: String,
            component: any SceneComponent,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:]
        ) -> StandaloneNodeDescriptor {
            StandaloneNodeDescriptor(
                id: id,
                kind: kind,
                component: component,
                spacingAfter: spacingAfter,
                metadata: metadata
            )
        }

        public func makeCustomStandaloneNode(
            id: String,
            kind: String,
            reuseIdentifier: String,
            signature: String,
            revealUnitCount: Int = 0,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:],
            makeView: @escaping () -> UIView,
            configure: @escaping (UIView, CGFloat) -> Void,
            reveal: ((UIView, RevealState) -> Void)? = nil,
            applyAppearance: ((UIView, AppearanceState) -> Void)? = nil
        ) -> StandaloneNodeDescriptor {
            let component = CustomViewSceneComponent(
                reuseIdentifier: reuseIdentifier,
                revealUnitCount: revealUnitCount,
                signature: signature,
                make: makeView,
                configure: configure,
                reveal: reveal,
                applyAppearance: applyAppearance
            )

            return StandaloneNodeDescriptor(
                id: id,
                kind: kind,
                component: component,
                spacingAfter: spacingAfter,
                metadata: metadata
            )
        }

        public func renderBlockAsDefault(_ block: RenderBlock, context: Context) throws -> [BlockMappingResult] {
            if let mapped = try mapCoreBlock(block, context: context) {
                return mapped
            }
            throw MarkdownContract.ModelError(
                code: .unknownNodeKind,
                message: "No default mapper handled \(block.kind.rawValue)",
                path: "RenderModelUIKitAdapter.block[\(block.id)]"
            )
        }

        fileprivate func mapBlocks(_ blocks: [RenderBlock], context: Context) throws -> [BlockMappingResult] {
            var results: [BlockMappingResult] = []
            results.reserveCapacity(blocks.count)
            for block in blocks {
                let mapped = try mapBlock(block, context: context)
                results.append(contentsOf: mapped)
            }
            return results
        }

        fileprivate func mapBlock(_ block: RenderBlock, context: Context) throws -> [BlockMappingResult] {
            let resolvedContext = context.applying(layoutHints: block.layoutHints)
            guard let mapped = try blockMapperChain.map(block: block, context: resolvedContext, adapter: self) else {
                throw MarkdownContract.ModelError(
                    code: .unknownNodeKind,
                    message: "No block mapper handled \(block.kind.rawValue)",
                    path: "RenderModelUIKitAdapter.block[\(block.id)]"
                )
            }
            return mapped
        }
    }
}

private extension MarkdownContract.RenderModelUIKitAdapter {
    struct InlineBaseStyle {
        let font: UIFont
        let color: UIColor
        let letterSpacing: CGFloat
    }

    typealias Mapper = MarkdownContract.BlockMapperChain.Mapper

    static let coreBlockHandlers: [String: Mapper] = {
        var handlers: [String: Mapper] = [:]
        handlers[MarkdownContract.BlockKind.document.rawValue] = { block, context, adapter in
            try adapter.mapDocumentBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.paragraph.rawValue] = { block, context, adapter in
            try adapter.mapParagraphBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.heading.rawValue] = { block, context, adapter in
            try adapter.mapHeadingBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.list.rawValue] = { block, context, adapter in
            try adapter.mapListBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.listItem.rawValue] = { block, context, adapter in
            try adapter.mapListItemBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.blockQuote.rawValue] = { block, context, adapter in
            try adapter.mapBlockQuoteBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.codeBlock.rawValue] = { block, context, adapter in
            try adapter.mapCodeBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.table.rawValue] = { block, context, adapter in
            try adapter.mapTableBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.thematicBreak.rawValue] = { block, context, adapter in
            try adapter.mapThematicBreakBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.image.rawValue] = { block, context, adapter in
            try adapter.mapImageBlock(block, context: context)
        }
        handlers[MarkdownContract.BlockKind.custom.rawValue] = { block, context, adapter in
            try adapter.mapCustomBlock(block, context: context)
        }
        return handlers
    }()

    func mapCoreBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult]? {
        for candidate in candidateKeys(for: block) {
            if let handler = Self.coreBlockHandlers[candidate] {
                return try handler(block, context, self)
            }
        }
        return nil
    }

    func mapDocumentBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        try mapBlocks(block.children, context: context)
    }

    func mapParagraphBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let attributed = renderInlines(
            block.inlines,
            in: block,
            context: context,
            baseStyle: defaultInlineBaseStyle(context: context)
        )
        guard attributed.length > 0 else { return [] }
        let quoteIndent = quoteTextIndent(for: context)

        let styled = applyingTextLayout(
            to: attributed,
            lineHeight: context.blockQuoteDepth > 0 ? context.theme.blockQuote.lineHeight : context.theme.body.lineHeight,
            letterSpacing: context.theme.body.letterSpacing,
            firstLineHeadIndent: context.indent + quoteIndent,
            headIndent: context.indent + quoteIndent,
            blockQuoteDepth: context.blockQuoteDepth
        )

        let segment = makeMergeTextSegment(
            sourceBlockID: block.id,
            kind: "paragraph",
            attributedText: styled,
            spacingAfter: blockSpacing(for: .paragraph, theme: context.theme, layoutHints: block.layoutHints),
            metadata: block.metadata
        )
        return [.mergeSegment(segment)]
    }

    func mapHeadingBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let level = block.contractAttrInt(for: "level") ?? 1
        let attributed = renderHeadingInlines(block.inlines, level: level, context: context)
        guard attributed.length > 0 else { return [] }

        let segment = makeMergeTextSegment(
            sourceBlockID: block.id,
            kind: "heading",
            attributedText: attributed,
            spacingAfter: blockSpacing(for: .heading, theme: context.theme, layoutHints: block.layoutHints),
            metadata: block.metadata
        )
        return [.mergeSegment(segment)]
    }

    func mapListBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let ordered = block.contractAttrBool(for: "ordered") ?? false
        let startIndex = block.contractAttrInt(for: "startIndex") ?? 1
        let baseContext = context
            .enteringList(ordered: ordered)
            .withListItemIndex(startIndex - 1)

        var results: [MarkdownContract.BlockMappingResult] = []
        var runningIndex = startIndex - 1

        for child in block.children {
            let childContext: Context
            if child.kind == .listItem {
                childContext = baseContext.withListItemIndex(runningIndex)
                runningIndex += 1
            } else {
                childContext = baseContext
            }
            results.append(contentsOf: try mapBlock(child, context: childContext))
        }

        return results
    }

    func mapListItemBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let marker: String
        if context.isOrderedList {
            marker = "\((context.listItemIndex ?? 0) + 1). "
        } else {
            marker = "\(context.theme.list.unorderedSymbol) "
        }

        var remainingChildren = block.children
        let textBody: NSAttributedString

        if !block.inlines.isEmpty {
            textBody = renderInlines(
                block.inlines,
                in: block,
                context: context,
                baseStyle: defaultInlineBaseStyle(context: context)
            )
        } else if let firstChild = block.children.first, firstChild.kind == .paragraph {
            let mergedParagraph = renderInlines(
                firstChild.inlines,
                in: firstChild,
                context: context,
                baseStyle: defaultInlineBaseStyle(context: context)
            )
            if mergedParagraph.length > 0 {
                textBody = mergedParagraph
                remainingChildren.removeFirst()
            } else {
                textBody = NSAttributedString(string: "")
            }
        } else {
            textBody = NSAttributedString(string: "")
        }

        let markerFont = context.theme.list.orderedNumberFont
        let markerWidth = (marker as NSString).size(withAttributes: [.font: markerFont]).width

        let merged = NSMutableAttributedString(
            string: marker,
            attributes: [
                .font: markerFont,
                .foregroundColor: context.theme.list.symbolColor,
                .xhsBaseForegroundColor: context.theme.list.symbolColor
            ]
        )
        merged.append(textBody)

        var results: [MarkdownContract.BlockMappingResult] = []
        if merged.length > 0 {
            let quoteIndent = quoteTextIndent(for: context)
            let styled = applyingTextLayout(
                to: merged,
                lineHeight: context.blockQuoteDepth > 0 ? context.theme.blockQuote.lineHeight : context.theme.body.lineHeight,
                letterSpacing: context.theme.body.letterSpacing,
                firstLineHeadIndent: context.indent + quoteIndent,
                headIndent: context.indent + quoteIndent + markerWidth,
                blockQuoteDepth: context.blockQuoteDepth
            )

            let segment = makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "listItem",
                attributedText: styled,
                spacingAfter: blockSpacing(for: .listItem, theme: context.theme, layoutHints: block.layoutHints),
                metadata: block.metadata
            )
            results.append(.mergeSegment(segment))
        }

        if !remainingChildren.isEmpty {
            results.append(contentsOf: try mapBlocks(remainingChildren, context: context))
        }

        return results
    }

    func mapBlockQuoteBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        var children = try mapBlocks(block.children, context: context.enteringBlockQuote())
        guard !children.isEmpty else { return [] }

        let extraSpacing = blockSpacing(for: .blockQuote, theme: context.theme, layoutHints: block.layoutHints)
        if let last = children.last {
            children[children.count - 1] = last.addingSpacingAfter(extraSpacing)
        }
        return children
    }

    func mapCodeBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let code = block.contractAttrString(for: "code") ?? block.inlines.map(\.text).joined()
        let language = block.contractAttrString(for: "language")

        let component = CodeBlockSceneComponent(
            code: code,
            language: language,
            font: context.theme.code.font,
            textColor: context.theme.code.block.textColor,
            backgroundColor: context.theme.code.block.backgroundColor,
            cornerRadius: context.theme.code.block.cornerRadius,
            padding: context.theme.code.block.padding,
            borderWidth: context.theme.code.block.borderWidth,
            borderColor: context.theme.code.block.borderColor
        )

        let node = makeStandaloneNode(
            id: block.id,
            kind: "codeBlock",
            component: component,
            spacingAfter: blockSpacing(for: .codeBlock, theme: context.theme, layoutHints: block.layoutHints),
            metadata: block.metadata
        )

        return [.standalone(node)]
    }

    func mapTableBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let tableComponent = try makeTableSceneComponent(block: block, context: context)

        let node = makeStandaloneNode(
            id: block.id,
            kind: "table",
            component: tableComponent,
            spacingAfter: blockSpacing(for: .table, theme: context.theme, layoutHints: block.layoutHints),
            metadata: block.metadata
        )

        return [.standalone(node)]
    }

    func mapThematicBreakBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let node = makeStandaloneNode(
            id: block.id,
            kind: "thematicBreak",
            component: RuleSceneComponent(
                color: context.theme.thematicBreak.color,
                height: context.theme.thematicBreak.height,
                verticalPadding: context.theme.thematicBreak.verticalPadding
            ),
            spacingAfter: blockSpacing(for: .thematicBreak, theme: context.theme, layoutHints: block.layoutHints),
            metadata: block.metadata
        )
        return [.standalone(node)]
    }

    func mapImageBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let altText = block.contractAttrString(for: "altText") ?? "[image]"
        let source = block.contractAttrString(for: "source")

        let node = makeStandaloneNode(
            id: block.id,
            kind: "image",
            component: ImagePlaceholderSceneComponent(
                altText: altText,
                source: source,
                placeholderColor: context.theme.image.placeholderColor,
                cornerRadius: context.theme.image.cornerRadius,
                placeholderHeight: context.theme.image.placeholderHeight,
                textFont: context.theme.body.font,
                textColor: context.theme.body.color
            ),
            spacingAfter: blockSpacing(for: .image, theme: context.theme, layoutHints: block.layoutHints),
            metadata: block.metadata
        )

        return [.standalone(node)]
    }

    func mapCustomBlock(_ block: MarkdownContract.RenderBlock, context: Context) throws -> [MarkdownContract.BlockMappingResult] {
        let attributed = renderInlines(
            block.inlines,
            in: block,
            context: context,
            baseStyle: defaultInlineBaseStyle(context: context)
        )
        if attributed.length > 0 {
            let quoteIndent = quoteTextIndent(for: context)
            let styled = applyingTextLayout(
                to: attributed,
                lineHeight: context.blockQuoteDepth > 0 ? context.theme.blockQuote.lineHeight : context.theme.body.lineHeight,
                letterSpacing: context.theme.body.letterSpacing,
                firstLineHeadIndent: context.indent + quoteIndent,
                headIndent: context.indent + quoteIndent,
                blockQuoteDepth: context.blockQuoteDepth
            )

            let segment = makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "custom",
                attributedText: styled,
                spacingAfter: block.layoutHints.spacingAfter.map { CGFloat($0) } ?? context.theme.spacing.paragraph,
                metadata: block.metadata
            )
            return [.mergeSegment(segment)]
        }

        return try mapBlocks(block.children, context: context)
    }

    func merge(mappedResults: [MarkdownContract.BlockMappingResult], theme: MarkdownTheme) -> [RenderScene.Node] {
        var nodes: [RenderScene.Node] = []
        var buffer: [MarkdownContract.MergeTextSegment] = []

        func flushBuffer() {
            guard !buffer.isEmpty else { return }

            let id = mergePolicy.mergedNodeID(for: buffer)
            let kind = mergePolicy.mergedNodeKind(for: buffer)
            let spacingAfter = mergePolicy.mergedNodeSpacingAfter(for: buffer)
            var metadata = mergePolicy.mergedNodeMetadata(for: buffer)
            if metadata["memberBlockIDs"] == nil {
                metadata["memberBlockIDs"] = .array(buffer.map { .string($0.sourceBlockID) })
            }
            if metadata["memberKinds"] == nil {
                metadata["memberKinds"] = .array(buffer.map { .string($0.kind) })
            }

            let text = mergedAttributedText(from: buffer)
            let component = MergedTextSceneComponent(
                attributedText: text,
                quoteBarColor: theme.blockQuote.barColor,
                quoteBarWidth: theme.blockQuote.barWidth,
                quoteNestingIndent: theme.blockQuote.nestingIndent
            )

            nodes.append(RenderScene.Node(
                id: id,
                kind: kind,
                component: component,
                spacingAfter: spacingAfter,
                metadata: metadata
            ))
            buffer.removeAll(keepingCapacity: true)
        }

        for item in mappedResults {
            switch item {
            case let .standalone(standalone):
                flushBuffer()
                nodes.append(RenderScene.Node(
                    id: standalone.id,
                    kind: standalone.kind,
                    component: standalone.component,
                    spacingAfter: standalone.spacingAfter,
                    metadata: standalone.metadata
                ))

            case let .mergeSegment(segment):
                if let previous = buffer.last {
                    let canMerge = mergePolicy.shouldMerge(previous: previous, next: segment)
                    if canMerge {
                        buffer.append(segment)
                    } else {
                        flushBuffer()
                        buffer.append(segment)
                    }
                } else {
                    buffer.append(segment)
                }

                if mergePolicy.shouldBreak(after: segment) {
                    flushBuffer()
                }
            }
        }

        flushBuffer()
        return nodes
    }

    func mergedAttributedText(from segments: [MarkdownContract.MergeTextSegment]) -> NSAttributedString {
        let merged = NSMutableAttributedString()

        for (index, segment) in segments.enumerated() {
            let normalized = NSMutableAttributedString(attributedString: segment.attributedText)
            applyParagraphSpacing(segment.spacingAfter, to: normalized)
            merged.append(normalized)

            if index < segments.count - 1 {
                merged.append(NSAttributedString(string: "\n"))
            }
        }

        return merged
    }

    func applyParagraphSpacing(_ spacing: CGFloat, to attributed: NSMutableAttributedString) {
        guard spacing > 0 else { return }
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard fullRange.length > 0 else { return }

        attributed.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            let base = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            base.paragraphSpacing = max(base.paragraphSpacing, spacing)
            attributed.addAttribute(.paragraphStyle, value: base, range: range)
        }
    }

    func renderHeadingInlines(_ inlines: [MarkdownContract.InlineSpan], level: Int, context: Context) -> NSAttributedString {
        let headingStyle = InlineBaseStyle(
            font: context.theme.heading.font(for: level),
            color: context.theme.heading.color(for: level),
            letterSpacing: context.theme.body.letterSpacing
        )
        let attributed = NSMutableAttributedString(attributedString: renderInlines(
            inlines,
            in: .init(id: "", kind: .heading),
            context: context,
            baseStyle: headingStyle
        ))
        guard attributed.length > 0 else { return attributed }
        let quoteIndent = quoteTextIndent(for: context)

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = context.theme.heading.lineHeight(for: level)
        paragraph.maximumLineHeight = context.theme.heading.lineHeight(for: level)
        paragraph.firstLineHeadIndent = context.indent + quoteIndent
        paragraph.headIndent = context.indent + quoteIndent
        paragraph.paragraphSpacingBefore = context.theme.spacing.headingSpacingBefore(for: level)

        attributed.addAttributes([
            .font: context.theme.heading.font(for: level),
            .foregroundColor: context.theme.heading.color(for: level),
            .xhsBaseForegroundColor: context.theme.heading.color(for: level),
            .paragraphStyle: paragraph,
            .kern: context.theme.body.letterSpacing
        ], range: NSRange(location: 0, length: attributed.length))

        if context.blockQuoteDepth > 0 {
            attributed.addAttribute(.xhsBlockQuoteDepth, value: context.blockQuoteDepth, range: NSRange(location: 0, length: attributed.length))
        }

        return attributed
    }

    func renderInlines(
        _ inlines: [MarkdownContract.InlineSpan],
        in block: MarkdownContract.RenderBlock,
        context: Context,
        baseStyle: InlineBaseStyle
    ) -> NSAttributedString {
        let merged = NSMutableAttributedString()

        for span in inlines {
            if let custom = renderInlineOverride(span, block: block, context: context) {
                merged.append(annotateBaseForegroundColor(in: custom, fallback: context.theme.body.color))
                continue
            }

            merged.append(defaultInline(span, block: block, context: context, baseStyle: baseStyle))
        }

        return merged
    }

    func renderInlineOverride(
        _ span: MarkdownContract.InlineSpan,
        block: MarkdownContract.RenderBlock,
        context: Context
    ) -> NSAttributedString? {
        for candidate in candidateKeys(for: span) {
            if let override = inlineRenderers[candidate], let rendered = override(span, block, context, self) {
                return rendered
            }
        }
        return nil
    }

    func defaultInline(
        _ span: MarkdownContract.InlineSpan,
        block: MarkdownContract.RenderBlock,
        context: Context,
        baseStyle: InlineBaseStyle
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: baseStyle.font,
            .foregroundColor: baseStyle.color,
            .xhsBaseForegroundColor: baseStyle.color
        ]

        if baseStyle.letterSpacing != 0 {
            attributes[.kern] = baseStyle.letterSpacing
        }

        let coreKind = span.kind.coreKind
        let text: String
        switch coreKind {
        case .softBreak?:
            text = "\n"
        case .hardBreak?:
            text = "\n"
        case .image?:
            text = span.contractAttrString(for: "altText") ?? "[image]"
        default:
            text = span.text
        }

        if span.kind == .inlineCode {
            attributes[.font] = context.theme.code.font
            attributes[.foregroundColor] = context.theme.code.inlineColor
            attributes[.xhsBaseForegroundColor] = context.theme.code.inlineColor
            if let background = context.theme.code.inlineBackgroundColor {
                attributes[.backgroundColor] = background
            }
        }

        if span.kind == .link {
            if let destination = span.contractAttrString(for: "destination") {
                attributes[.link] = destination
            }
            attributes[.foregroundColor] = context.theme.link.color
            attributes[.xhsBaseForegroundColor] = context.theme.link.color
            if context.theme.link.underlineStyle != [] {
                attributes[.underlineStyle] = context.theme.link.underlineStyle.rawValue
            }
        }

        for mark in span.marks {
            apply(mark: mark, to: &attributes, block: block, context: context)
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    func apply(
        mark: MarkdownContract.MarkToken,
        to attributes: inout [NSAttributedString.Key: Any],
        block: MarkdownContract.RenderBlock,
        context: Context
    ) {
        if mark.name == "strong" || mark.name == "bold" {
            if let font = attributes[.font] as? UIFont {
                attributes[.font] = font.bold
            }
            return
        }

        if mark.name == "emphasis" || mark.name == "italic" {
            if let font = attributes[.font] as? UIFont {
                attributes[.font] = font.italic
            }
            return
        }

        if mark.name == "strikethrough" {
            attributes[.strikethroughStyle] = context.theme.strikethrough.style.rawValue
            if let color = context.theme.strikethrough.color {
                attributes[.strikethroughColor] = color
            }
            return
        }

        if mark.name == "link" {
            if case let .object(attrs)? = mark.value,
               case let .string(destination)? = attrs["destination"] {
                attributes[.link] = destination
            }
            attributes[.foregroundColor] = context.theme.link.color
            attributes[.xhsBaseForegroundColor] = context.theme.link.color
            if context.theme.link.underlineStyle != [] {
                attributes[.underlineStyle] = context.theme.link.underlineStyle.rawValue
            }
            return
        }

        customMarkAttributeResolver?(mark, &attributes, block, context)
    }

    func blockSpacing(for kind: MarkdownContract.BlockKind, theme: MarkdownTheme, layoutHints: MarkdownContract.LayoutHints) -> CGFloat {
        if let explicit = layoutHints.spacingAfter {
            return CGFloat(explicit)
        }

        let coreKind = kind.coreKind
        if coreKind == .heading {
            return theme.spacing.headingAfter
        }
        if coreKind == .listItem {
            return theme.spacing.listItem
        }
        if coreKind == .blockQuote {
            return theme.spacing.blockQuoteOther
        }
        if coreKind == .thematicBreak {
            return 0
        }
        return theme.spacing.paragraph
    }

    func applyingTextLayout(
        to attributed: NSAttributedString,
        lineHeight: CGFloat,
        letterSpacing: CGFloat,
        firstLineHeadIndent: CGFloat,
        headIndent: CGFloat,
        blockQuoteDepth: Int
    ) -> NSAttributedString {
        let styled = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: styled.length)
        guard fullRange.length > 0 else { return styled }

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.firstLineHeadIndent = firstLineHeadIndent
        paragraph.headIndent = headIndent

        styled.addAttribute(.paragraphStyle, value: paragraph, range: fullRange)
        if letterSpacing != 0 {
            styled.addAttribute(.kern, value: letterSpacing, range: fullRange)
        }

        if blockQuoteDepth > 0 {
            styled.addAttribute(.xhsBlockQuoteDepth, value: blockQuoteDepth, range: fullRange)
        }

        return annotateBaseForegroundColor(in: styled, fallback: .label)
    }

    func annotateBaseForegroundColor(in attributed: NSAttributedString, fallback: UIColor) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let range = NSRange(location: 0, length: mutable.length)
        guard range.length > 0 else { return mutable }

        mutable.enumerateAttribute(.foregroundColor, in: range, options: []) { value, subrange, _ in
            let color = (value as? UIColor) ?? fallback
            mutable.addAttribute(.foregroundColor, value: color, range: subrange)
            mutable.addAttribute(.xhsBaseForegroundColor, value: color, range: subrange)
        }

        return mutable
    }

    func makeTableSceneComponent(
        block: MarkdownContract.RenderBlock,
        context: Context
    ) throws -> TableSceneComponent {
        guard let headBlock = block.children.first(where: { $0.kind.coreKind == .tableHead }) else {
            throw MarkdownContract.ModelError(
                code: .schemaInvalid,
                message: "Table block requires tableHead child",
                path: "RenderModelUIKitAdapter.block[\(block.id)]"
            )
        }
        guard let bodyBlock = block.children.first(where: { $0.kind.coreKind == .tableBody }) else {
            throw MarkdownContract.ModelError(
                code: .schemaInvalid,
                message: "Table block requires tableBody child",
                path: "RenderModelUIKitAdapter.block[\(block.id)]"
            )
        }
        let headerRows = tableRows(in: headBlock)
        guard let firstHeaderRow = headerRows.first, !firstHeaderRow.isEmpty else {
            throw MarkdownContract.ModelError(
                code: .schemaInvalid,
                message: "tableHead requires at least one tableCell",
                path: "RenderModelUIKitAdapter.block[\(block.id)]"
            )
        }
        let bodyRows = tableRows(in: bodyBlock)
        let headerText = firstHeaderRow.map { cell in
            renderTableCellText(cell: cell, isHeader: true, context: context)
        }

        let rowText = bodyRows.map { row in
            let rendered = row.map { cell in
                renderTableCellText(cell: cell, isHeader: false, context: context)
            }
            return normalizedRow(rendered, targetColumnCount: headerText.count)
        }

        let attrs = block.contractAttrs ?? [:]
        let alignmentValues = attrs["alignments"]?.arrayOptionalStringValues
            ?? attrs["columnAlignments"]?.arrayOptionalStringValues
            ?? []

        return TableSceneComponent(
            headers: headerText,
            rows: rowText,
            alignments: normalizedTableAlignments(values: alignmentValues, columnCount: headerText.count),
            headerBackgroundColor: context.theme.table.headerBackgroundColor,
            borderColor: context.theme.table.borderColor,
            cornerRadius: context.theme.table.cornerRadius,
            cellPadding: context.theme.table.cellPadding
        )
    }

    func renderTableCellText(
        cell: MarkdownContract.RenderBlock,
        isHeader: Bool,
        context: Context
    ) -> NSAttributedString {
        let cellInlines = tableCellInlines(from: cell)
        let rendered = renderInlines(
            cellInlines,
            in: cell,
            context: context,
            baseStyle: tableInlineBaseStyle(context: context, isHeader: isHeader)
        )

        guard rendered.length > 0 else {
            return NSAttributedString(string: "")
        }

        let mutable = NSMutableAttributedString(attributedString: rendered)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = context.theme.body.lineHeight
        paragraph.maximumLineHeight = context.theme.body.lineHeight
        paragraph.lineBreakMode = .byWordWrapping
        mutable.addAttribute(.paragraphStyle, value: paragraph, range: fullRange)
        return mutable
    }

    func tableCellInlines(from cell: MarkdownContract.RenderBlock) -> [MarkdownContract.InlineSpan] {
        if !cell.inlines.isEmpty {
            return cell.inlines
        }

        var merged: [MarkdownContract.InlineSpan] = []
        let paragraphChildren = cell.children.filter { $0.kind.coreKind == .paragraph }
        for (index, paragraph) in paragraphChildren.enumerated() {
            merged.append(contentsOf: paragraph.inlines)
            if index < paragraphChildren.count - 1 {
                merged.append(.init(
                    id: "\(cell.id).softBreak.\(index)",
                    kind: .softBreak,
                    text: "\n"
                ))
            }
        }
        return merged
    }

    func tableRows(in section: MarkdownContract.RenderBlock) -> [[MarkdownContract.RenderBlock]] {
        let rowBlocks = section.children.filter { $0.kind.coreKind == .tableRow }
        if !rowBlocks.isEmpty {
            return rowBlocks.map { row in
                row.children.filter { $0.kind.coreKind == .tableCell }
            }
        }

        let directCells = section.children.filter { $0.kind.coreKind == .tableCell }
        if !directCells.isEmpty {
            return [directCells]
        }

        return []
    }

    func normalizedRow(_ row: [NSAttributedString], targetColumnCount: Int) -> [NSAttributedString] {
        guard targetColumnCount > 0 else { return [] }
        if row.count == targetColumnCount {
            return row
        }
        if row.count > targetColumnCount {
            return Array(row.prefix(targetColumnCount))
        }
        var padded = row
        padded.append(contentsOf: Array(repeating: NSAttributedString(string: ""), count: targetColumnCount - row.count))
        return padded
    }

    func quoteTextIndent(for context: Context) -> CGFloat {
        guard context.blockQuoteDepth > 0 else { return 0 }
        let style = context.theme.blockQuote
        let levelOffset = CGFloat(max(0, context.blockQuoteDepth - 1)) * style.nestingIndent
        return levelOffset + max(1, style.barWidth) + max(0, style.barLeftMargin)
    }

    func defaultInlineBaseStyle(context: Context) -> InlineBaseStyle {
        let inQuote = context.blockQuoteDepth > 0
        return InlineBaseStyle(
            font: inQuote ? context.theme.blockQuote.font : context.theme.body.font,
            color: inQuote ? context.theme.blockQuote.textColor : context.theme.body.color,
            letterSpacing: context.theme.body.letterSpacing
        )
    }

    func tableInlineBaseStyle(context: Context, isHeader: Bool) -> InlineBaseStyle {
        InlineBaseStyle(
            font: isHeader ? context.theme.table.headerFont : context.theme.table.font,
            color: context.theme.table.textColor,
            letterSpacing: 0
        )
    }

    func normalizedTableAlignments(
        values: [String?],
        columnCount: Int
    ) -> [TableSceneComponent.ColumnAlignment] {
        guard columnCount > 0 else {
            return []
        }

        var alignments = values.map { raw -> TableSceneComponent.ColumnAlignment in
            guard let raw else { return .left }
            if raw.lowercased() == "center" {
                return .center
            }
            if raw.lowercased() == "right" {
                return .right
            }
            return .left
        }

        if alignments.count < columnCount {
            alignments.append(contentsOf: Array(repeating: .left, count: columnCount - alignments.count))
        } else if alignments.count > columnCount {
            alignments = Array(alignments.prefix(columnCount))
        }
        return alignments
    }

    func candidateKeys(for block: MarkdownContract.RenderBlock) -> [String] {
        var candidates: [String] = []
        if case let .ext(extensionKind) = block.kind {
            candidates.append("ext:\(extensionKind.rawValue)")
        }
        candidates.append(key(for: block.kind))
        return candidates
    }

    func candidateKeys(for span: MarkdownContract.InlineSpan) -> [String] {
        var candidates: [String] = []
        if case let .ext(extensionKind) = span.kind {
            candidates.append("ext:\(extensionKind.rawValue)")
        }
        candidates.append(key(for: span.kind))
        return candidates
    }

    func key(for kind: MarkdownContract.NodeKind) -> String {
        kind.rawValue
    }
}

public extension MarkdownContract.RenderBlock {
    var contractAttrs: [String: MarkdownContract.Value]? {
        if case let .object(attrs)? = metadata["attrs"] {
            return attrs
        }
        return nil
    }

    func contractAttrString(for key: String) -> String? {
        if case let .string(value)? = metadata[key] {
            return value
        }

        if case let .object(attrs)? = metadata["attrs"], case let .string(value)? = attrs[key] {
            return value
        }

        if case let .string(value)? = additionalFields[key] {
            return value
        }

        return nil
    }

    func contractAttrBool(for key: String) -> Bool? {
        if case let .bool(value)? = metadata[key] {
            return value
        }

        if case let .object(attrs)? = metadata["attrs"], case let .bool(value)? = attrs[key] {
            return value
        }

        if case let .bool(value)? = additionalFields[key] {
            return value
        }

        return nil
    }

    func contractAttrInt(for key: String) -> Int? {
        if case let .int(value)? = metadata[key] {
            return value
        }

        if case let .object(attrs)? = metadata["attrs"], case let .int(value)? = attrs[key] {
            return value
        }

        if case let .int(value)? = additionalFields[key] {
            return value
        }

        return nil
    }
}

private extension MarkdownContract.Value {
    var arrayStringValues: [String]? {
        guard case let .array(values) = self else {
            return nil
        }
        return values.compactMap { value in
            if case let .string(raw) = value {
                return raw
            }
            return nil
        }
    }

    var arrayOfArrayStringValues: [[String]]? {
        guard case let .array(values) = self else {
            return nil
        }
        return values.map { value in
            guard case let .array(inner) = value else {
                return []
            }
            return inner.map { innerValue in
                if case let .string(raw) = innerValue {
                    return raw
                }
                return ""
            }
        }
    }

    var arrayOptionalStringValues: [String?]? {
        guard case let .array(values) = self else {
            return nil
        }
        return values.map { value in
            switch value {
            case let .string(raw):
                return raw
            case .null:
                return nil
            default:
                return nil
            }
        }
    }
}

public extension MarkdownContract.InlineSpan {
    func contractAttrString(for key: String) -> String? {
        if case let .string(value)? = metadata[key] {
            return value
        }

        if case let .object(attrs)? = metadata["attrs"], case let .string(value)? = attrs[key] {
            return value
        }

        if case let .string(value)? = additionalFields[key] {
            return value
        }

        return nil
    }
}
