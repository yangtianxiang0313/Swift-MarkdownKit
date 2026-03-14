import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

extension MarkdownContract {
    public protocol UIKitNodeRenderPlugin {
        func register(into adapter: RenderModelUIKitAdapter)
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

        public typealias BlockRenderer = (_ block: RenderBlock, _ context: Context, _ adapter: RenderModelUIKitAdapter) -> [RenderScene.Node]
        public typealias InlineRenderer = (_ span: InlineSpan, _ block: RenderBlock, _ context: Context, _ adapter: RenderModelUIKitAdapter) -> NSAttributedString?
        public typealias CustomMarkAttributeResolver = (_ mark: MarkToken, _ attributes: inout [NSAttributedString.Key: Any], _ block: RenderBlock, _ context: Context) -> Void

        public var customMarkAttributeResolver: CustomMarkAttributeResolver?

        private var blockRenderers: [String: BlockRenderer] = [:]
        private var inlineRenderers: [String: InlineRenderer] = [:]

        public init(plugins: [UIKitNodeRenderPlugin] = []) {
            plugins.forEach { $0.register(into: self) }
        }

        public func registerBlockRenderer(for kind: BlockKind, renderer: @escaping BlockRenderer) {
            blockRenderers[key(for: kind)] = renderer
        }

        public func registerBlockRenderer(forKey key: String, renderer: @escaping BlockRenderer) {
            blockRenderers[key] = renderer
        }

        public func registerBlockRenderer(forExtension name: String, renderer: @escaping BlockRenderer) {
            blockRenderers["ext:\(name)"] = renderer
        }

        public func removeBlockRenderer(for kind: BlockKind) {
            blockRenderers.removeValue(forKey: key(for: kind))
        }

        public func removeBlockRenderer(forKey key: String) {
            blockRenderers.removeValue(forKey: key)
        }

        public func removeBlockRenderer(forExtension name: String) {
            blockRenderers.removeValue(forKey: "ext:\(name)")
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
        ) -> RenderScene {
            let context = Context(theme: theme, maxWidth: maxWidth)
            let nodes = renderBlocks(model.blocks, context: context)
            return RenderScene(documentId: model.documentId, nodes: nodes, metadata: model.metadata)
        }

        public func renderBlockAsDefault(_ block: RenderBlock, context: Context) -> [RenderScene.Node] {
            defaultRender(block: block, context: context)
        }

        public func makeTextNode(
            id: String,
            kind: String,
            text: NSAttributedString,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:]
        ) -> RenderScene.Node {
            RenderScene.Node(
                id: id,
                kind: kind,
                component: TextSceneComponent(attributedText: text),
                spacingAfter: spacingAfter,
                metadata: metadata
            )
        }

        public func makeCustomViewNode(
            id: String,
            kind: String,
            reuseIdentifier: String,
            signature: String,
            revealUnitCount: Int = 1,
            spacingAfter: CGFloat = 0,
            metadata: [String: Value] = [:],
            makeView: @escaping () -> UIView,
            configure: @escaping (UIView, CGFloat) -> Void,
            reveal: ((UIView, Int) -> Void)? = nil
        ) -> RenderScene.Node {
            let component = CustomViewSceneComponent(
                reuseIdentifier: reuseIdentifier,
                revealUnitCount: revealUnitCount,
                signature: signature,
                make: makeView,
                configure: configure,
                reveal: reveal
            )
            return RenderScene.Node(
                id: id,
                kind: kind,
                component: component,
                spacingAfter: spacingAfter,
                metadata: metadata
            )
        }

        fileprivate func renderBlocks(_ blocks: [RenderBlock], context: Context) -> [RenderScene.Node] {
            blocks.flatMap { renderBlock($0, context: context) }
        }

        fileprivate func renderBlock(_ block: RenderBlock, context: Context) -> [RenderScene.Node] {
            let resolvedContext = context.applying(layoutHints: block.layoutHints)

            for candidate in candidateKeys(for: block) {
                if let override = blockRenderers[candidate] {
                    return override(block, resolvedContext, self)
                }
            }

            return defaultRender(block: block, context: resolvedContext)
        }
    }
}

private extension MarkdownContract.RenderModelUIKitAdapter {
    func defaultRender(block: MarkdownContract.RenderBlock, context: Context) -> [RenderScene.Node] {
        switch block.kind.coreKind {
        case .document?:
            return renderBlocks(block.children, context: context)

        case .paragraph?:
            let attributed = renderInlines(block.inlines, in: block, context: context)
            guard attributed.length > 0 else { return [] }
            let styled = applyingTextLayout(
                to: attributed,
                lineHeight: context.blockQuoteDepth > 0 ? context.theme.blockQuote.lineHeight : context.theme.body.lineHeight,
                letterSpacing: context.theme.body.letterSpacing,
                firstLineHeadIndent: context.indent,
                headIndent: context.indent
            )
            return [makeContextualTextNode(
                id: block.id,
                kind: "paragraph",
                text: styled,
                spacingAfter: blockSpacing(for: .paragraph, theme: context.theme, layoutHints: block.layoutHints),
                metadata: block.metadata,
                context: context
            )]

        case .heading?:
            let level = block.contractAttrInt(for: "level") ?? 1
            let attributed = renderHeadingInlines(block.inlines, level: level, context: context)
            guard attributed.length > 0 else { return [] }
            return [makeContextualTextNode(
                id: block.id,
                kind: "heading",
                text: attributed,
                spacingAfter: blockSpacing(for: .heading, theme: context.theme, layoutHints: block.layoutHints),
                metadata: block.metadata,
                context: context
            )]

        case .list?:
            let ordered = block.contractAttrBool(for: "ordered") ?? false
            let startIndex = block.contractAttrInt(for: "startIndex") ?? 1
            let baseContext = context
                .enteringList(ordered: ordered)
                .withListItemIndex(startIndex - 1)

            var nodes: [RenderScene.Node] = []
            var runningIndex = startIndex - 1
            for child in block.children {
                let childContext: Context
                if child.kind == .listItem {
                    childContext = baseContext.withListItemIndex(runningIndex)
                    runningIndex += 1
                } else {
                    childContext = baseContext
                }
                nodes.append(contentsOf: renderBlock(child, context: childContext))
            }
            return nodes

        case .listItem?:
            let marker: String
            if context.isOrderedList {
                marker = "\((context.listItemIndex ?? 0) + 1). "
            } else {
                marker = "\(context.theme.list.unorderedSymbol) "
            }

            var remainingChildren = block.children
            let textBody: NSAttributedString
            if !block.inlines.isEmpty {
                textBody = renderInlines(block.inlines, in: block, context: context)
            } else if let firstChild = block.children.first, firstChild.kind == .paragraph {
                let mergedParagraph = renderInlines(firstChild.inlines, in: firstChild, context: context)
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
                    .foregroundColor: context.theme.list.symbolColor
                ]
            )
            merged.append(textBody)

            var nodes: [RenderScene.Node] = []
            if merged.length > 0 {
                let styled = applyingTextLayout(
                    to: merged,
                    lineHeight: context.blockQuoteDepth > 0 ? context.theme.blockQuote.lineHeight : context.theme.body.lineHeight,
                    letterSpacing: context.theme.body.letterSpacing,
                    firstLineHeadIndent: context.indent,
                    headIndent: context.indent + markerWidth
                )
                nodes.append(makeContextualTextNode(
                    id: block.id,
                    kind: "listItem",
                    text: styled,
                    spacingAfter: blockSpacing(for: .listItem, theme: context.theme, layoutHints: block.layoutHints),
                    metadata: block.metadata,
                    context: context
                ))
            }

            if !remainingChildren.isEmpty {
                nodes.append(contentsOf: renderBlocks(remainingChildren, context: context))
            }

            return nodes

        case .blockQuote?:
            let childContext = context.enteringBlockQuote()
            let children = renderBlocks(block.children, context: childContext)
            if children.isEmpty { return [] }

            return [RenderScene.Node(
                id: block.id,
                kind: "blockQuote",
                component: BlockQuoteContainerSceneComponent(
                    barColor: context.theme.blockQuote.barColor,
                    barWidth: context.theme.blockQuote.barWidth,
                    contentLeadingInset: context.theme.blockQuote.nestingIndent,
                    contentInsets: .zero,
                    fillColor: nil
                ),
                children: children,
                spacingAfter: blockSpacing(for: .blockQuote, theme: context.theme, layoutHints: block.layoutHints),
                metadata: block.metadata
            )]

        case .codeBlock?:
            let code = block.contractAttrString(for: "code") ?? block.inlines.map(\.text).joined()
            let language = block.contractAttrString(for: "language")
            return [RenderScene.Node(
                id: block.id,
                kind: "codeBlock",
                component: CodeBlockSceneComponent(
                    code: code,
                    language: language,
                    font: context.theme.code.font,
                    textColor: context.theme.code.block.textColor,
                    backgroundColor: context.theme.code.block.backgroundColor,
                    cornerRadius: context.theme.code.block.cornerRadius,
                    padding: context.theme.code.block.padding,
                    borderWidth: context.theme.code.block.borderWidth,
                    borderColor: context.theme.code.block.borderColor
                ),
                spacingAfter: blockSpacing(for: .codeBlock, theme: context.theme, layoutHints: block.layoutHints),
                metadata: block.metadata
            )]

        case .table?:
            if let tableComponent = makeTableSceneComponent(block: block, context: context) {
                return [RenderScene.Node(
                    id: block.id,
                    kind: "table",
                    component: tableComponent,
                    spacingAfter: blockSpacing(for: .table, theme: context.theme, layoutHints: block.layoutHints),
                    metadata: block.metadata
                )]
            }

            let attributed = renderInlines(block.inlines, in: block, context: context)
            if attributed.length > 0 {
                return [makeContextualTextNode(
                    id: block.id,
                    kind: "table",
                    text: attributed,
                    spacingAfter: blockSpacing(for: .table, theme: context.theme, layoutHints: block.layoutHints),
                    metadata: block.metadata,
                    context: context
                )]
            }
            return renderBlocks(block.children, context: context)

        case .thematicBreak?:
            return [RenderScene.Node(
                id: block.id,
                kind: "thematicBreak",
                component: RuleSceneComponent(
                    color: context.theme.thematicBreak.color,
                    height: context.theme.thematicBreak.height,
                    verticalPadding: context.theme.thematicBreak.verticalPadding
                ),
                spacingAfter: blockSpacing(for: .thematicBreak, theme: context.theme, layoutHints: block.layoutHints),
                metadata: block.metadata
            )]

        case .image?:
            let altText = block.contractAttrString(for: "altText") ?? "[image]"
            let source = block.contractAttrString(for: "source")
            return [RenderScene.Node(
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
            )]

        case .custom?:
            let attributed = renderInlines(block.inlines, in: block, context: context)
            if attributed.length > 0 {
                return [makeContextualTextNode(
                    id: block.id,
                    kind: "custom",
                    text: attributed,
                    spacingAfter: block.layoutHints.spacingAfter.map { CGFloat($0) } ?? context.theme.spacing.paragraph,
                    metadata: block.metadata,
                    context: context
                )]
            }
            return renderBlocks(block.children, context: context)

        default:
            let attributed = renderInlines(block.inlines, in: block, context: context)
            if attributed.length > 0 {
                return [makeContextualTextNode(
                    id: block.id,
                    kind: block.kind.rawValue,
                    text: attributed,
                    spacingAfter: block.layoutHints.spacingAfter.map { CGFloat($0) } ?? context.theme.spacing.paragraph,
                    metadata: block.metadata,
                    context: context
                )]
            }
            return renderBlocks(block.children, context: context)
        }
    }

    func renderHeadingInlines(_ inlines: [MarkdownContract.InlineSpan], level: Int, context: Context) -> NSAttributedString {
        let attributed = NSMutableAttributedString(attributedString: renderInlines(inlines, in: .init(id: "", kind: .heading), context: context))
        guard attributed.length > 0 else { return attributed }

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = context.theme.heading.lineHeight(for: level)
        paragraph.maximumLineHeight = context.theme.heading.lineHeight(for: level)
        paragraph.firstLineHeadIndent = context.indent
        paragraph.headIndent = context.indent
        paragraph.paragraphSpacingBefore = context.theme.spacing.headingSpacingBefore(for: level)

        attributed.addAttributes([
            .font: context.theme.heading.font(for: level),
            .foregroundColor: context.theme.heading.color(for: level),
            .paragraphStyle: paragraph,
            .kern: context.theme.body.letterSpacing
        ], range: NSRange(location: 0, length: attributed.length))

        return attributed
    }

    func renderInlines(
        _ inlines: [MarkdownContract.InlineSpan],
        in block: MarkdownContract.RenderBlock,
        context: Context
    ) -> NSAttributedString {
        let merged = NSMutableAttributedString()

        for span in inlines {
            if let custom = renderInlineOverride(span, block: block, context: context) {
                merged.append(custom)
                continue
            }

            merged.append(defaultInline(span, block: block, context: context))
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
        context: Context
    ) -> NSAttributedString {
        let blockQuoteDepth = context.blockQuoteDepth
        let baseColor = blockQuoteDepth > 0 ? context.theme.blockQuote.textColor : context.theme.body.color
        let baseFont = blockQuoteDepth > 0 ? context.theme.blockQuote.font : context.theme.body.font
        var baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor
        ]

        if context.theme.body.letterSpacing != 0 {
            baseAttributes[.kern] = context.theme.body.letterSpacing
        }

        let text: String
        switch span.kind.coreKind {
        case .softBreak?:
            text = "\n"
        case .hardBreak?:
            text = "\n"
        case .image?:
            text = span.contractAttrString(for: "altText") ?? "[image]"
        default:
            text = span.text
        }

        var attributes = baseAttributes

        for mark in span.marks {
            apply(mark: mark, to: &attributes, span: span, block: block, context: context)
        }

        if span.kind == .inlineCode {
            attributes[.font] = context.theme.code.font
            attributes[.foregroundColor] = context.theme.code.inlineColor
            if let background = context.theme.code.inlineBackgroundColor {
                attributes[.backgroundColor] = background
            }
        }

        if span.kind == .link {
            if let destination = span.contractAttrString(for: "destination") {
                attributes[.link] = destination
            }
            attributes[.foregroundColor] = context.theme.link.color
            if context.theme.link.underlineStyle != [] {
                attributes[.underlineStyle] = context.theme.link.underlineStyle.rawValue
            }
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    func apply(
        mark: MarkdownContract.MarkToken,
        to attributes: inout [NSAttributedString.Key: Any],
        span: MarkdownContract.InlineSpan,
        block: MarkdownContract.RenderBlock,
        context: Context
    ) {
        switch mark.name {
        case "strong", "bold":
            if let font = attributes[.font] as? UIFont {
                attributes[.font] = font.bold
            }
        case "emphasis", "italic":
            if let font = attributes[.font] as? UIFont {
                attributes[.font] = font.italic
            }
        case "strikethrough":
            attributes[.strikethroughStyle] = context.theme.strikethrough.style.rawValue
            if let color = context.theme.strikethrough.color {
                attributes[.strikethroughColor] = color
            }
        default:
            customMarkAttributeResolver?(mark, &attributes, block, context)
        }
    }

    func blockSpacing(for kind: MarkdownContract.BlockKind, theme: MarkdownTheme, layoutHints: MarkdownContract.LayoutHints) -> CGFloat {
        if let explicit = layoutHints.spacingAfter {
            return CGFloat(explicit)
        }

        switch kind.coreKind {
        case .heading?:
            return theme.spacing.headingAfter
        case .listItem?:
            return theme.spacing.listItem
        case .blockQuote?:
            return theme.spacing.blockQuoteOther
        case .thematicBreak?:
            return 0
        default:
            return theme.spacing.paragraph
        }
    }

    func makeTableSceneComponent(
        block: MarkdownContract.RenderBlock,
        context: Context
    ) -> TableSceneComponent? {
        guard let attrs = block.contractAttrs else {
            return nil
        }

        guard let headers = attrs["headers"]?.arrayStringValues, !headers.isEmpty else {
            return nil
        }

        let rows = attrs["rows"]?.arrayOfArrayStringValues ?? []
        let alignmentValues = attrs["alignments"]?.arrayOptionalStringValues
            ?? attrs["columnAlignments"]?.arrayOptionalStringValues
            ?? []

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = context.theme.body.lineHeight
        paragraph.maximumLineHeight = context.theme.body.lineHeight
        paragraph.lineBreakMode = .byWordWrapping

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: context.theme.table.headerFont,
            .foregroundColor: context.theme.table.textColor,
            .paragraphStyle: paragraph
        ]

        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: context.theme.table.font,
            .foregroundColor: context.theme.table.textColor,
            .paragraphStyle: paragraph
        ]

        let headerText = headers.map {
            NSAttributedString(string: $0, attributes: headerAttributes)
        }
        let rowText = rows.map { row in
            row.map { NSAttributedString(string: $0, attributes: cellAttributes) }
        }

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

    func normalizedTableAlignments(
        values: [String?],
        columnCount: Int
    ) -> [TableSceneComponent.ColumnAlignment] {
        guard columnCount > 0 else {
            return []
        }

        var alignments = values.map { raw -> TableSceneComponent.ColumnAlignment in
            guard let raw else { return .left }
            switch raw.lowercased() {
            case "center":
                return .center
            case "right":
                return .right
            default:
                return .left
            }
        }

        if alignments.count < columnCount {
            alignments.append(contentsOf: Array(repeating: .left, count: columnCount - alignments.count))
        } else if alignments.count > columnCount {
            alignments = Array(alignments.prefix(columnCount))
        }
        return alignments
    }

    func makeContextualTextNode(
        id: String,
        kind: String,
        text: NSAttributedString,
        spacingAfter: CGFloat,
        metadata: [String: MarkdownContract.Value],
        context: Context
    ) -> RenderScene.Node {
        _ = context
        return makeTextNode(
            id: id,
            kind: kind,
            text: text,
            spacingAfter: spacingAfter,
            metadata: metadata
        )
    }

    func applyingTextLayout(
        to attributed: NSAttributedString,
        lineHeight: CGFloat,
        letterSpacing: CGFloat,
        firstLineHeadIndent: CGFloat,
        headIndent: CGFloat
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
        return styled
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
