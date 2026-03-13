import UIKit

extension MarkdownContract {
    public final class RenderModelUIKitAdapter {
        public struct Context {
            public var theme: MarkdownTheme
            public var maxWidth: CGFloat
            public var indent: CGFloat
            public var listDepth: Int
            public var isOrderedList: Bool
            public var listItemIndex: Int?
            public var listMarker: NSAttributedString?
            public var blockQuoteDepth: Int

            public init(
                theme: MarkdownTheme,
                maxWidth: CGFloat,
                indent: CGFloat = 0,
                listDepth: Int = 0,
                isOrderedList: Bool = false,
                listItemIndex: Int? = nil,
                listMarker: NSAttributedString? = nil,
                blockQuoteDepth: Int = 0
            ) {
                self.theme = theme
                self.maxWidth = maxWidth
                self.indent = indent
                self.listDepth = listDepth
                self.isOrderedList = isOrderedList
                self.listItemIndex = listItemIndex
                self.listMarker = listMarker
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
                next.listMarker = nil
                return next
            }

            func withListItemIndex(_ index: Int?) -> Context {
                var next = self
                next.listItemIndex = index
                return next
            }

            func withListMarker(_ marker: NSAttributedString?) -> Context {
                var next = self
                next.listMarker = marker
                return next
            }

            func enteringBlockQuote() -> Context {
                var next = self
                next.blockQuoteDepth += 1
                return next
            }

            func makeFragmentContext() -> FragmentContext {
                var fragmentContext = FragmentContext()
                fragmentContext[IndentKey.self] = indent
                fragmentContext[BlockQuoteDepthKey.self] = blockQuoteDepth
                fragmentContext[ListDepthKey.self] = listDepth
                fragmentContext[MaxWidthKey.self] = maxWidth
                fragmentContext[ListItemIndexKey.self] = listItemIndex
                fragmentContext[IsOrderedListKey.self] = isOrderedList
                return fragmentContext
            }
        }

        public typealias BlockRenderer = (_ block: RenderBlock, _ context: Context, _ adapter: RenderModelUIKitAdapter) -> [RenderFragment]
        public typealias InlineRenderer = (_ span: InlineSpan, _ block: RenderBlock, _ context: Context, _ adapter: RenderModelUIKitAdapter) -> NSAttributedString?
        public typealias CustomMarkAttributeResolver = (_ mark: MarkToken, _ attributes: inout [NSAttributedString.Key: Any], _ block: RenderBlock, _ context: Context) -> Void

        public var spacingResolver: any BlockSpacingResolving
        public var textViewStrategy: any TextViewStrategy
        public var codeBlockViewStrategy: any CodeBlockViewStrategy
        public var imageViewStrategy: any ImageViewStrategy
        public var thematicBreakViewStrategy: any ThematicBreakViewStrategy
        public var tableViewStrategy: any TableViewStrategy
        public var customMarkAttributeResolver: CustomMarkAttributeResolver?

        private var blockRenderers: [String: BlockRenderer] = [:]
        private var inlineRenderers: [String: InlineRenderer] = [:]

        public init(
            spacingResolver: any BlockSpacingResolving = DefaultBlockSpacingResolver(),
            textViewStrategy: any TextViewStrategy = DefaultContractTextViewStrategy(),
            codeBlockViewStrategy: any CodeBlockViewStrategy = DefaultContractCodeBlockViewStrategy(),
            imageViewStrategy: any ImageViewStrategy = DefaultContractImageViewStrategy(),
            thematicBreakViewStrategy: any ThematicBreakViewStrategy = DefaultContractThematicBreakViewStrategy(),
            tableViewStrategy: any TableViewStrategy = DefaultContractTableViewStrategy()
        ) {
            self.spacingResolver = spacingResolver
            self.textViewStrategy = textViewStrategy
            self.codeBlockViewStrategy = codeBlockViewStrategy
            self.imageViewStrategy = imageViewStrategy
            self.thematicBreakViewStrategy = thematicBreakViewStrategy
            self.tableViewStrategy = tableViewStrategy
        }

        public func registerBlockRenderer(
            for kind: BlockKind,
            renderer: @escaping BlockRenderer
        ) {
            blockRenderers[key(for: kind)] = renderer
        }

        /// Register override by raw block key (`heading`, `custom`, etc.).
        public func registerBlockRenderer(
            forKey key: String,
            renderer: @escaping BlockRenderer
        ) {
            blockRenderers[key] = renderer
        }

        /// Register override for contract custom elements where `attrs.name == name`.
        /// For HTML custom elements, block-level tags trigger this path while inline tags stay inline.
        public func registerBlockRenderer(
            forCustomElement name: String,
            renderer: @escaping BlockRenderer
        ) {
            blockRenderers["custom:\(name)"] = renderer
        }

        public func removeBlockRenderer(for kind: BlockKind) {
            blockRenderers.removeValue(forKey: key(for: kind))
        }

        public func removeBlockRenderer(forKey key: String) {
            blockRenderers.removeValue(forKey: key)
        }

        public func removeBlockRenderer(forCustomElement name: String) {
            blockRenderers.removeValue(forKey: "custom:\(name)")
        }

        public func registerInlineRenderer(
            for kind: InlineKind,
            renderer: @escaping InlineRenderer
        ) {
            inlineRenderers[key(for: kind)] = renderer
        }

        /// Register inline override by raw inline key (`text`, `custom`, etc.).
        public func registerInlineRenderer(
            forKey key: String,
            renderer: @escaping InlineRenderer
        ) {
            inlineRenderers[key] = renderer
        }

        /// Register inline override for contract custom elements where `attrs.name == name`.
        public func registerInlineRenderer(
            forCustomElement name: String,
            renderer: @escaping InlineRenderer
        ) {
            inlineRenderers["custom:\(name)"] = renderer
        }

        public func removeInlineRenderer(for kind: InlineKind) {
            inlineRenderers.removeValue(forKey: key(for: kind))
        }

        public func removeInlineRenderer(forKey key: String) {
            inlineRenderers.removeValue(forKey: key)
        }

        public func removeInlineRenderer(forCustomElement name: String) {
            inlineRenderers.removeValue(forKey: "custom:\(name)")
        }

        public func render(
            model: RenderModel,
            theme: MarkdownTheme,
            maxWidth: CGFloat
        ) -> [RenderFragment] {
            let context = Context(theme: theme, maxWidth: maxWidth)
            let fragments = renderBlocks(model.blocks, context: context)
            var optimized = removeEmptyTextFragments(fragments)
            applySpacing(to: &optimized, theme: theme)
            applyLayoutHintSpacing(to: &optimized, blockLookup: blockLookup(from: model.blocks))
            return optimized
        }

        public func renderBlockAsDefault(
            _ block: RenderBlock,
            context: Context
        ) -> [RenderFragment] {
            defaultRender(block: block, context: context)
        }

        fileprivate func renderBlocks(
            _ blocks: [RenderBlock],
            context: Context
        ) -> [RenderFragment] {
            blocks.flatMap { renderBlock($0, context: context) }
        }

        fileprivate func renderBlock(
            _ block: RenderBlock,
            context: Context
        ) -> [RenderFragment] {
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
    func removeEmptyTextFragments(_ fragments: [RenderFragment]) -> [RenderFragment] {
        fragments.filter { fragment in
            if let attrProvider = fragment as? AttributedStringProviding,
               let attrString = attrProvider.attributedString,
               attrString.length == 0 {
                return false
            }
            return true
        }
    }

    func applySpacing(
        to fragments: inout [RenderFragment],
        theme: MarkdownTheme
    ) {
        for index in fragments.indices {
            if index < fragments.count - 1 {
                fragments[index].spacingAfter = spacingResolver.spacing(
                    after: fragments[index].nodeType,
                    before: fragments[index + 1].nodeType,
                    theme: theme
                )
            } else {
                fragments[index].spacingAfter = 0
            }
        }
    }

    func defaultRender(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        switch block.kind {
        case .document:
            return renderBlocks(block.children, context: context)
        case .paragraph:
            return renderParagraph(block: block, context: context)
        case .heading:
            return renderHeading(block: block, context: context)
        case .list:
            return renderList(block: block, context: context)
        case .listItem:
            return renderListItem(block: block, context: context)
        case .blockQuote:
            return renderBlockQuote(block: block, context: context)
        case .codeBlock:
            return renderCodeBlock(block: block, context: context)
        case .table:
            return renderTable(block: block, context: context)
        case .thematicBreak:
            return renderThematicBreak(block: block, context: context)
        case .image:
            return renderImage(block: block, context: context)
        case .custom, .customRaw:
            return renderCustomBlock(block: block, context: context)
        }
    }

    func renderParagraph(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        guard var attributedString = renderInlineSpans(
            block.inlines,
            block: block,
            context: context,
            baseAttributes: bodyAttributes(theme: context.theme, block: block)
        ) else {
            return []
        }

        if let marker = context.listMarker {
            let merged = NSMutableAttributedString(attributedString: marker)
            merged.append(attributedString)
            attributedString = merged
        }

        return [makeTextFragment(
            fragmentId: block.id,
            nodeType: .paragraph,
            attributedString: attributedString,
            context: context
        )]
    }

    func renderHeading(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let level = block.attrs["level"]?.intValue ?? 1
        guard let attributedString = renderInlineSpans(
            block.inlines,
            block: block,
            context: context,
            baseAttributes: headingAttributes(
                level: level,
                theme: context.theme,
                block: block
            )
        ) else {
            return []
        }

        return [makeTextFragment(
            fragmentId: block.id,
            nodeType: .heading(level),
            attributedString: attributedString,
            context: context
        )]
    }

    func renderCodeBlock(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let code = block.attrs["code"]?.stringValue
            ?? block.metadata["sourceRaw"]?.stringValue
            ?? block.inlines.map(\.text).joined()
        let language = block.attrs["language"]?.stringValue
        let content = CodeBlockContent(
            code: code,
            language: language,
            stateKey: "\(code.hashValue)_\(language ?? "")"
        )
        let fragmentContext = context.makeFragmentContext()
        let strategy = codeBlockViewStrategy
        let theme = context.theme

        return [ContractViewFragment(
            fragmentId: block.id,
            nodeType: .codeBlock,
            reuseIdentifier: .contractCodeBlockView,
            context: fragmentContext,
            content: content,
            totalContentLength: code.count,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(
                    view: view,
                    content: content,
                    context: fragmentContext,
                    theme: theme
                )
            }
        )]
    }

    func renderThematicBreak(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let fragmentContext = context.makeFragmentContext()
        let strategy = thematicBreakViewStrategy
        let theme = context.theme

        return [ContractViewFragment(
            fragmentId: block.id,
            nodeType: .thematicBreak,
            reuseIdentifier: .contractThematicBreakView,
            context: fragmentContext,
            content: EmptyFragmentContent(),
            totalContentLength: 1,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, context: fragmentContext, theme: theme)
            }
        )]
    }

    func renderImage(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let content = ImageContent(
            source: block.metadata["source"]?.stringValue ?? block.attrs["source"]?.stringValue,
            title: block.attrs["title"]?.stringValue,
            altText: block.attrs["altText"]?.stringValue ?? ""
        )
        let fragmentContext = context.makeFragmentContext()
        let strategy = imageViewStrategy
        let theme = context.theme

        return [ContractViewFragment(
            fragmentId: block.id,
            nodeType: .image,
            reuseIdentifier: .contractImageView,
            context: fragmentContext,
            content: content,
            totalContentLength: 1,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(
                    view: view,
                    content: content,
                    context: fragmentContext,
                    theme: theme
                )
            }
        )]
    }

    func renderBlockQuote(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        var children = renderBlocks(block.children, context: context.enteringBlockQuote())
        if children.isEmpty {
            children = renderParagraph(block: block, context: context.enteringBlockQuote())
        }
        guard !children.isEmpty else { return [] }

        let config = ContractBlockQuoteContainerConfiguration(
            childFragments: children,
            depth: 1,
            barColor: context.theme.blockQuote.barColor,
            barWidth: context.theme.blockQuote.barWidth,
            barLeftMargin: context.theme.blockQuote.barLeftMargin
        )

        return [ContractBlockQuoteContainerFragment(
            fragmentId: block.id,
            config: config
        )]
    }

    func renderList(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let ordered = block.attrs["ordered"]?.boolValue ?? false
        let startIndex = block.attrs["startIndex"]?.intValue ?? 1
        let listContext = context.enteringList(ordered: ordered)

        return block.children.enumerated().flatMap { index, child in
            let itemContext = listContext.withListItemIndex(startIndex + index)
            return renderBlock(child, context: itemContext)
        }
    }

    func renderListItem(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let marker = makeListMarker(block: block, context: context)
        if block.children.isEmpty {
            guard let marker else { return [] }
            return [makeTextFragment(
                fragmentId: block.id,
                nodeType: .listItem,
                attributedString: marker,
                context: context
            )]
        }

        var fragments: [RenderFragment] = []
        for (index, child) in block.children.enumerated() {
            let childContext: MarkdownContract.RenderModelUIKitAdapter.Context
            if index == 0 {
                childContext = context.withListMarker(marker)
            } else {
                childContext = context.withListMarker(nil)
            }
            fragments.append(contentsOf: renderBlock(child, context: childContext))
        }
        return fragments
    }

    func renderTable(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        if let tableData = makeTableData(block: block, theme: context.theme) {
            let fragmentContext = context.makeFragmentContext()
            let strategy = tableViewStrategy
            let theme = context.theme

            return [ContractViewFragment(
                fragmentId: block.id,
                nodeType: .table,
                reuseIdentifier: .contractTableView,
                context: fragmentContext,
                content: tableData,
                totalContentLength: 1,
                enterTransition: strategy.enterTransition,
                exitTransition: strategy.exitTransition,
                makeView: { strategy.makeView() },
                configure: { view in
                    strategy.configure(
                        view: view,
                        tableData: tableData,
                        context: fragmentContext,
                        theme: theme
                    )
                }
            )]
        }

        let children = renderBlocks(block.children, context: context)
        if !children.isEmpty {
            return children
        }
        return renderParagraph(block: block, context: context)
    }

    func renderCustomBlock(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> [RenderFragment] {
        let children = renderBlocks(block.children, context: context)
        if !children.isEmpty {
            return children
        }

        if !block.inlines.isEmpty {
            return renderParagraph(block: block, context: context)
        }

        if let raw = block.metadata["sourceRaw"]?.stringValue, !raw.isEmpty {
            let attributed = NSAttributedString(
                string: raw,
                attributes: bodyAttributes(theme: context.theme, block: block)
            )
            return [makeTextFragment(
                fragmentId: block.id,
                nodeType: FragmentNodeType(rawValue: "custom"),
                attributedString: attributed,
                context: context
            )]
        }

        return []
    }

    func makeTextFragment(
        fragmentId: String,
        nodeType: FragmentNodeType,
        attributedString: NSAttributedString,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> RenderFragment {
        let fragmentContext = context.makeFragmentContext()
        let strategy = textViewStrategy
        let theme = context.theme
        return ContractTextFragment(
            fragmentId: fragmentId,
            nodeType: nodeType,
            reuseIdentifier: .contractTextView,
            context: fragmentContext,
            attributedString: attributedString,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view, renderedText in
                strategy.configure(
                    view: view,
                    attributedString: renderedText,
                    context: fragmentContext,
                    theme: theme
                )
            }
        )
    }
}

private extension MarkdownContract.RenderModelUIKitAdapter {
    func renderInlineSpans(
        _ spans: [MarkdownContract.InlineSpan],
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context,
        baseAttributes: [NSAttributedString.Key: Any]
    ) -> NSMutableAttributedString? {
        guard !spans.isEmpty else { return nil }
        let result = NSMutableAttributedString()

        for span in spans {
            var hasCustomInline = false
            for candidate in candidateKeys(for: span) {
                guard let override = inlineRenderers[candidate] else { continue }
                hasCustomInline = true
                if let fragment = override(span, block, context, self), fragment.length > 0 {
                    result.append(fragment)
                }
                break
            }
            if hasCustomInline {
                continue
            }

            let text = inlineText(for: span)
            if text.isEmpty {
                continue
            }

            var attributes = baseAttributes
            applyInlineKindAttributes(span.kind, attributes: &attributes, context: context)
            applyMarkAttributes(span.marks, attributes: &attributes, block: block, context: context)

            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        return result.length > 0 ? result : nil
    }

    func inlineText(for span: MarkdownContract.InlineSpan) -> String {
        switch span.kind {
        case .softBreak:
            return " "
        case .hardBreak:
            return "\n"
        default:
            return span.text
        }
    }

    func applyInlineKindAttributes(
        _ kind: MarkdownContract.InlineKind,
        attributes: inout [NSAttributedString.Key: Any],
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) {
        switch kind {
        case .code:
            applyInlineCodeAttributes(attributes: &attributes, theme: context.theme)
        default:
            break
        }
    }

    func applyMarkAttributes(
        _ marks: [MarkdownContract.MarkToken],
        attributes: inout [NSAttributedString.Key: Any],
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) {
        for mark in marks {
            switch mark.name {
            case "strong":
                if let font = attributes[.font] as? UIFont {
                    attributes[.font] = font.bold
                }
            case "emphasis":
                applyEmphasisAttributes(attributes: &attributes, theme: context.theme)
            case "link":
                attributes[.foregroundColor] = context.theme.link.color
                if context.theme.link.underlineStyle != [] {
                    attributes[.underlineStyle] = context.theme.link.underlineStyle.rawValue
                }
                if let destination = mark.value?.objectValue?["destination"]?.stringValue,
                   let url = URL(string: destination) {
                    attributes[.link] = url
                }
            case "inlineCode":
                applyInlineCodeAttributes(attributes: &attributes, theme: context.theme)
            default:
                customMarkAttributeResolver?(mark, &attributes, block, context)
            }
        }
    }

    func applyInlineCodeAttributes(
        attributes: inout [NSAttributedString.Key: Any],
        theme: MarkdownTheme
    ) {
        attributes[.font] = theme.code.font
        attributes[.foregroundColor] = theme.code.inlineColor
        if let background = theme.code.inlineBackgroundColor {
            attributes[.backgroundColor] = background
        }
    }

    func applyEmphasisAttributes(
        attributes: inout [NSAttributedString.Key: Any],
        theme: MarkdownTheme
    ) {
        switch theme.emphasis.type {
        case .italic:
            if let font = attributes[.font] as? UIFont {
                let italicFont = font.italic
                if italicFont.isItalic {
                    attributes[.font] = italicFont
                } else {
                    attributes[.obliqueness] = NSNumber(value: 0.2)
                }
            }
        case .highlight:
            attributes[.backgroundColor] = theme.emphasis.highlightColor
        case .both:
            if let font = attributes[.font] as? UIFont {
                let italicFont = font.italic
                if italicFont.isItalic {
                    attributes[.font] = italicFont
                } else {
                    attributes[.obliqueness] = NSNumber(value: 0.2)
                }
            }
            attributes[.backgroundColor] = theme.emphasis.highlightColor
        }
    }
}

private extension MarkdownContract.RenderModelUIKitAdapter {
    func bodyAttributes(
        theme: MarkdownTheme,
        block: MarkdownContract.RenderBlock
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = theme.body.lineHeight
        paragraphStyle.maximumLineHeight = theme.body.lineHeight

        var attributes: [NSAttributedString.Key: Any] = [
            .font: theme.body.font,
            .foregroundColor: theme.body.color,
            .paragraphStyle: paragraphStyle,
            .kern: theme.body.letterSpacing,
            .baselineOffset: (theme.body.lineHeight - theme.body.font.lineHeight) / 4
        ]

        applyStyleTokens(block.styleTokens, attributes: &attributes, baseTheme: theme)
        return attributes
    }

    func headingAttributes(
        level: Int,
        theme: MarkdownTheme,
        block: MarkdownContract.RenderBlock
    ) -> [NSAttributedString.Key: Any] {
        let headingFont = theme.heading.font(for: level)
        let lineHeight = theme.heading.lineHeight(for: level)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight

        var attributes: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: theme.heading.color(for: level),
            .paragraphStyle: paragraphStyle,
            .baselineOffset: (lineHeight - headingFont.lineHeight) / 4
        ]

        applyStyleTokens(block.styleTokens, attributes: &attributes, baseTheme: theme)
        return attributes
    }

    func applyStyleTokens(
        _ tokens: [MarkdownContract.StyleToken],
        attributes: inout [NSAttributedString.Key: Any],
        baseTheme: MarkdownTheme
    ) {
        for token in tokens {
            switch token.value {
            case .color(let colorValue):
                guard token.name == "text.color"
                    || token.name == "foregroundColor"
                    || token.name == "color"
                else {
                    continue
                }
                if let color = UIColor(contractColor: colorValue) {
                    attributes[.foregroundColor] = color
                }
            case .typography(let typography):
                let weight = UIFont.Weight(rawValue: CGFloat(typography.weight) / 1000.0)
                let font = UIFont.systemFont(ofSize: CGFloat(typography.size), weight: weight)
                attributes[.font] = font

                if let lineHeight = typography.lineHeight {
                    let paragraphStyle = (attributes[.paragraphStyle] as? NSMutableParagraphStyle)
                        ?? NSMutableParagraphStyle()
                    paragraphStyle.minimumLineHeight = CGFloat(lineHeight)
                    paragraphStyle.maximumLineHeight = CGFloat(lineHeight)
                    attributes[.paragraphStyle] = paragraphStyle
                    attributes[.baselineOffset] = (CGFloat(lineHeight) - font.lineHeight) / 4
                }

                if let letterSpacing = typography.letterSpacing {
                    attributes[.kern] = CGFloat(letterSpacing)
                }
            case .number(let value):
                if token.name == "letterSpacing" || token.name == "text.letterSpacing" {
                    attributes[.kern] = CGFloat(value)
                }
                if token.name == "opacity",
                   let color = attributes[.foregroundColor] as? UIColor {
                    attributes[.foregroundColor] = color.withAlphaComponent(CGFloat(value))
                }
            default:
                _ = baseTheme
            }
        }
    }
}

private extension MarkdownContract.RenderModelUIKitAdapter {
    func makeListMarker(
        block: MarkdownContract.RenderBlock,
        context: MarkdownContract.RenderModelUIKitAdapter.Context
    ) -> NSAttributedString? {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: context.theme.body.font,
            .foregroundColor: context.theme.body.color
        ]

        if let checked = block.attrs["checkbox"]?.boolValue {
            let symbol = checked ? "☑ " : "☐ "
            return NSAttributedString(string: symbol, attributes: attributes)
        }

        if context.isOrderedList {
            let index = context.listItemIndex ?? 1
            return NSAttributedString(string: "\(index). ", attributes: attributes)
        }

        let depth = max(1, context.listDepth)
        let bullet: String
        switch (depth - 1) % 3 {
        case 0:
            bullet = "•"
        case 1:
            bullet = "◦"
        default:
            bullet = "▪"
        }

        return NSAttributedString(string: "\(bullet) ", attributes: attributes)
    }

    func makeTableData(
        block: MarkdownContract.RenderBlock,
        theme: MarkdownTheme
    ) -> TableData? {
        guard let headers = block.attrs["headers"]?.arrayValue?.compactMap(\.stringValue),
              let rows = block.attrs["rows"]?.arrayValue?
                .compactMap(\.arrayValue)
                .map({ $0.compactMap(\.stringValue) }),
              !headers.isEmpty
        else {
            return nil
        }

        let alignments: [TableColumnAlignment]
        if let values = block.attrs["alignments"]?.arrayValue {
            alignments = values.map {
                switch $0.stringValue {
                case "center":
                    return .center
                case "right":
                    return .right
                case "left":
                    return .left
                default:
                    return .none
                }
            }
        } else {
            alignments = Array(repeating: .left, count: headers.count)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = theme.body.lineHeight
        paragraphStyle.maximumLineHeight = theme.body.lineHeight
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.body.font,
            .foregroundColor: theme.body.color,
            .paragraphStyle: paragraphStyle
        ]

        return TableData(
            headers: headers.map { NSAttributedString(string: $0, attributes: cellAttributes) },
            rows: rows.map { row in
                row.map { NSAttributedString(string: $0, attributes: cellAttributes) }
            },
            alignments: alignments
        )
    }
}

private extension MarkdownContract.RenderModelUIKitAdapter {
    func candidateKeys(for block: MarkdownContract.RenderBlock) -> [String] {
        var keys: [String] = [key(for: block.kind)]

        if let name = block.attrs["name"]?.stringValue {
            keys.insert("custom:\(name)", at: 0)
        }

        if case .customRaw = block.kind {
            keys.append("custom")
        }

        if block.kind == .custom {
            keys.append("custom")
        }

        return keys
    }

    func key(for kind: MarkdownContract.BlockKind) -> String {
        switch kind {
        case .document:
            return "document"
        case .paragraph:
            return "paragraph"
        case .heading:
            return "heading"
        case .list:
            return "list"
        case .listItem:
            return "listItem"
        case .blockQuote:
            return "blockQuote"
        case .codeBlock:
            return "codeBlock"
        case .table:
            return "table"
        case .thematicBreak:
            return "thematicBreak"
        case .image:
            return "image"
        case .custom:
            return "custom"
        case .customRaw(let raw):
            return raw
        }
    }

    func key(for kind: MarkdownContract.InlineKind) -> String {
        switch kind {
        case .text:
            return "text"
        case .code:
            return "code"
        case .link:
            return "link"
        case .image:
            return "image"
        case .softBreak:
            return "softBreak"
        case .hardBreak:
            return "hardBreak"
        case .custom:
            return "custom"
        case .customRaw(let raw):
            return raw
        }
    }

    func candidateKeys(for span: MarkdownContract.InlineSpan) -> [String] {
        var keys: [String] = [key(for: span.kind)]

        if let name = span.attrs["name"]?.stringValue {
            keys.insert("custom:\(name)", at: 0)
        }

        if case .customRaw = span.kind {
            keys.append("custom")
        }

        if span.kind == .custom {
            keys.append("custom")
        }

        return keys
    }

    func blockLookup(
        from blocks: [MarkdownContract.RenderBlock]
    ) -> [String: MarkdownContract.RenderBlock] {
        var lookup: [String: MarkdownContract.RenderBlock] = [:]

        func walk(_ block: MarkdownContract.RenderBlock) {
            lookup[block.id] = block
            for child in block.children {
                walk(child)
            }
        }

        for block in blocks {
            walk(block)
        }

        return lookup
    }

    func applyLayoutHintSpacing(
        to fragments: inout [RenderFragment],
        blockLookup: [String: MarkdownContract.RenderBlock]
    ) {
        for index in fragments.indices {
            let fragment = fragments[index]
            guard let block = blockLookup[fragment.fragmentId] else { continue }
            if let spacingAfter = block.layoutHints.spacingAfter {
                fragments[index].spacingAfter = CGFloat(spacingAfter)
            }
        }
    }
}

private extension MarkdownContract.RenderBlock {
    var attrs: [String: MarkdownContract.Value] {
        metadata["attrs"]?.objectValue ?? [:]
    }
}

private extension MarkdownContract.InlineSpan {
    var attrs: [String: MarkdownContract.Value] {
        metadata["attrs"]?.objectValue ?? [:]
    }
}

private extension MarkdownContract.Value {
    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        if case let .int(value) = self {
            return value
        }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self {
            return value
        }
        return nil
    }

    var objectValue: [String: MarkdownContract.Value]? {
        if case let .object(value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [MarkdownContract.Value]? {
        if case let .array(value) = self {
            return value
        }
        return nil
    }
}

private extension UIColor {
    convenience init?(contractColor: MarkdownContract.ColorValue) {
        if let appearance = contractColor.appearance,
           let light = appearance.light,
           let color = UIColor(contractFlatColor: light) {
            self.init(cgColor: color.cgColor)
            return
        }

        if let color = UIColor(contractFlatColor: .init(
            token: contractColor.token,
            hex: contractColor.hex,
            rgba: contractColor.rgba
        )) {
            self.init(cgColor: color.cgColor)
            return
        }

        return nil
    }

    convenience init?(contractFlatColor: MarkdownContract.ColorValue.FlatColor) {
        if let rgba = contractFlatColor.rgba {
            let scale = max(rgba.r, rgba.g, rgba.b) > 1 ? 255.0 : 1.0
            self.init(
                red: rgba.r / scale,
                green: rgba.g / scale,
                blue: rgba.b / scale,
                alpha: rgba.a
            )
            return
        }

        if let hex = contractFlatColor.hex,
           let color = UIColor(hex: hex) {
            self.init(cgColor: color.cgColor)
            return
        }

        return nil
    }

    convenience init?(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexValue.hasPrefix("#") {
            hexValue.removeFirst()
        }

        guard hexValue.count == 6 || hexValue.count == 8 else {
            return nil
        }

        var intValue: UInt64 = 0
        guard Scanner(string: hexValue).scanHexInt64(&intValue) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if hexValue.count == 8 {
            red = CGFloat((intValue & 0xFF00_0000) >> 24) / 255
            green = CGFloat((intValue & 0x00FF_0000) >> 16) / 255
            blue = CGFloat((intValue & 0x0000_FF00) >> 8) / 255
            alpha = CGFloat(intValue & 0x0000_00FF) / 255
        } else {
            red = CGFloat((intValue & 0xFF00_00) >> 16) / 255
            green = CGFloat((intValue & 0x00FF_00) >> 8) / 255
            blue = CGFloat(intValue & 0x0000_FF) / 255
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
