import UIKit

// MARK: - MarkdownTheme

public struct MarkdownTheme {
    public static let `default` = MarkdownTheme()

    public var body: BodyStyle = .default
    public var heading: HeadingStyle = .default
    public var code: CodeStyle = .default
    public var blockQuote: BlockQuoteStyle = .default
    public var link: LinkStyle = .default
    public var list: ListStyle = .default
    public var table: TableStyle = .default
    public var thematicBreak: ThematicBreakStyle = .default
    public var image: ImageStyle = .default
    public var spacing: SpacingStyle = .default
    public var emphasis: EmphasisStyle = .default
    public var strikethrough: StrikethroughStyle = .default

    public init() {}
}

// MARK: - BodyStyle

public extension MarkdownTheme {
    struct BodyStyle {
        public var font: UIFont
        public var color: UIColor
        public var lineHeight: CGFloat
        public var letterSpacing: CGFloat

        public static let `default` = BodyStyle(
            font: .systemFont(ofSize: 15, weight: .regular),
            color: .label,
            lineHeight: 25.0,
            letterSpacing: 0.32
        )

        public init(font: UIFont = Self.default.font, color: UIColor = Self.default.color,
                     lineHeight: CGFloat = Self.default.lineHeight, letterSpacing: CGFloat = Self.default.letterSpacing) {
            self.font = font; self.color = color; self.lineHeight = lineHeight; self.letterSpacing = letterSpacing
        }
    }
}

// MARK: - HeadingStyle

public extension MarkdownTheme {
    struct HeadingStyle {
        public var fontSizes: [CGFloat]
        public var fontWeights: [UIFont.Weight]
        public var lineHeights: [CGFloat]
        public var color: UIColor
        public var colors: [UIColor?]

        public static let `default` = HeadingStyle(
            fontSizes: [28, 24, 20, 18, 16, 15],
            fontWeights: [.bold, .bold, .semibold, .semibold, .semibold, .medium],
            lineHeights: [36, 32, 28, 26, 24, 22],
            color: .label, colors: [nil, nil, nil, nil, nil, nil]
        )

        public init(fontSizes: [CGFloat] = Self.default.fontSizes, fontWeights: [UIFont.Weight] = Self.default.fontWeights,
                     lineHeights: [CGFloat] = Self.default.lineHeights, color: UIColor = Self.default.color,
                     colors: [UIColor?] = Self.default.colors) {
            self.fontSizes = fontSizes; self.fontWeights = fontWeights; self.lineHeights = lineHeights
            self.color = color; self.colors = colors
        }

        public func font(for level: Int) -> UIFont {
            let i = max(0, min(level - 1, 5))
            return .systemFont(ofSize: fontSizes[safe: i] ?? fontSizes[0], weight: fontWeights[safe: i] ?? fontWeights[0])
        }

        public func color(for level: Int) -> UIColor {
            let i = max(0, min(level - 1, 5))
            return colors[safe: i].flatMap { $0 } ?? color
        }

        public func lineHeight(for level: Int) -> CGFloat {
            let i = max(0, min(level - 1, 5))
            return lineHeights[safe: i] ?? lineHeights[0]
        }
    }
}

// MARK: - CodeStyle

public extension MarkdownTheme {
    struct CodeStyle {
        public var font: UIFont
        public var inlineColor: UIColor
        public var inlineBackgroundColor: UIColor?
        public var letterSpacing: CGFloat
        public var block: CodeBlockStyle

        public static let `default` = CodeStyle(
            font: .monospacedSystemFont(ofSize: 14, weight: .regular),
            inlineColor: .secondaryLabel,
            inlineBackgroundColor: UIColor.systemGray5.withAlphaComponent(0.85),
            letterSpacing: 0,
            block: .default
        )

        public init(font: UIFont = Self.default.font, inlineColor: UIColor = Self.default.inlineColor,
                     inlineBackgroundColor: UIColor? = Self.default.inlineBackgroundColor,
                     letterSpacing: CGFloat = Self.default.letterSpacing, block: CodeBlockStyle = Self.default.block) {
            self.font = font; self.inlineColor = inlineColor; self.inlineBackgroundColor = inlineBackgroundColor
            self.letterSpacing = letterSpacing; self.block = block
        }
    }

    struct CodeBlockStyle {
        public var backgroundColor: UIColor
        public var textColor: UIColor
        public var cornerRadius: CGFloat
        public var padding: UIEdgeInsets
        public var borderWidth: CGFloat
        public var borderColor: UIColor

        public static let `default` = CodeBlockStyle(
            backgroundColor: .secondarySystemBackground,
            textColor: .label,
            cornerRadius: 10,
            padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
            borderWidth: 0.5, borderColor: .separator
        )

        public init(backgroundColor: UIColor = Self.default.backgroundColor,
                     textColor: UIColor = Self.default.textColor,
                     cornerRadius: CGFloat = Self.default.cornerRadius,
                     padding: UIEdgeInsets = Self.default.padding, borderWidth: CGFloat = Self.default.borderWidth,
                     borderColor: UIColor = Self.default.borderColor) {
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.borderWidth = borderWidth; self.borderColor = borderColor
        }
    }
}

// MARK: - BlockQuoteStyle

public extension MarkdownTheme {
    struct BlockQuoteStyle {
        public var font: UIFont
        public var textColor: UIColor
        public var lineHeight: CGFloat
        public var barColor: UIColor
        public var barWidth: CGFloat
        public var barLeftMargin: CGFloat
        public var nestingIndent: CGFloat

        public static let `default` = BlockQuoteStyle(
            font: .systemFont(ofSize: 15), textColor: .label, lineHeight: 25.0,
            barColor: .separator, barWidth: 3.0, barLeftMargin: 8.0, nestingIndent: 20.0
        )

        public init(font: UIFont = Self.default.font, textColor: UIColor = Self.default.textColor,
                     lineHeight: CGFloat = Self.default.lineHeight, barColor: UIColor = Self.default.barColor,
                     barWidth: CGFloat = Self.default.barWidth, barLeftMargin: CGFloat = Self.default.barLeftMargin,
                     nestingIndent: CGFloat = Self.default.nestingIndent) {
            self.font = font; self.textColor = textColor; self.lineHeight = lineHeight
            self.barColor = barColor; self.barWidth = barWidth; self.barLeftMargin = barLeftMargin
            self.nestingIndent = nestingIndent
        }
    }
}

// MARK: - LinkStyle

public extension MarkdownTheme {
    struct LinkStyle {
        public var color: UIColor
        public var underlineStyle: NSUnderlineStyle
        public static let `default` = LinkStyle(color: .systemBlue, underlineStyle: [])
        public init(color: UIColor = Self.default.color, underlineStyle: NSUnderlineStyle = Self.default.underlineStyle) {
            self.color = color; self.underlineStyle = underlineStyle
        }
    }
}

// MARK: - ListStyle

public extension MarkdownTheme {
    struct ListStyle {
        public var nestingIndent: CGFloat
        public var unorderedSymbol: String
        public var orderedNumberFont: UIFont
        public var symbolColor: UIColor

        public static let `default` = ListStyle(
            nestingIndent: 20.0, unorderedSymbol: "•",
            orderedNumberFont: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            symbolColor: .placeholderText
        )

        public init(nestingIndent: CGFloat = Self.default.nestingIndent, unorderedSymbol: String = Self.default.unorderedSymbol,
                     orderedNumberFont: UIFont = Self.default.orderedNumberFont, symbolColor: UIColor = Self.default.symbolColor) {
            self.nestingIndent = nestingIndent; self.unorderedSymbol = unorderedSymbol
            self.orderedNumberFont = orderedNumberFont; self.symbolColor = symbolColor
        }
    }
}

// MARK: - TableStyle

public extension MarkdownTheme {
    struct TableStyle {
        public var font: UIFont
        public var textColor: UIColor
        public var headerFont: UIFont
        public var headerBackgroundColor: UIColor
        public var borderColor: UIColor
        public var cornerRadius: CGFloat
        public var cellPadding: UIEdgeInsets

        public static let `default` = TableStyle(
            font: .systemFont(ofSize: 14), textColor: .label,
            headerFont: .systemFont(ofSize: 14, weight: .semibold),
            headerBackgroundColor: .secondarySystemBackground,
            borderColor: .separator, cornerRadius: 8.0,
            cellPadding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        )

        public init(font: UIFont = Self.default.font, textColor: UIColor = Self.default.textColor,
                     headerFont: UIFont = Self.default.headerFont, headerBackgroundColor: UIColor = Self.default.headerBackgroundColor,
                     borderColor: UIColor = Self.default.borderColor, cornerRadius: CGFloat = Self.default.cornerRadius,
                     cellPadding: UIEdgeInsets = Self.default.cellPadding) {
            self.font = font; self.textColor = textColor; self.headerFont = headerFont
            self.headerBackgroundColor = headerBackgroundColor; self.borderColor = borderColor
            self.cornerRadius = cornerRadius; self.cellPadding = cellPadding
        }
    }
}

// MARK: - ThematicBreakStyle

public extension MarkdownTheme {
    struct ThematicBreakStyle {
        public var color: UIColor
        public var height: CGFloat
        public var verticalPadding: CGFloat
        public static let `default` = ThematicBreakStyle(color: UIColor.black.withAlphaComponent(0.05), height: 1.0, verticalPadding: 7.5)
        public init(color: UIColor = Self.default.color, height: CGFloat = Self.default.height,
                     verticalPadding: CGFloat = Self.default.verticalPadding) {
            self.color = color; self.height = height; self.verticalPadding = verticalPadding
        }
    }
}

// MARK: - ImageStyle

public extension MarkdownTheme {
    struct ImageStyle {
        public var cornerRadius: CGFloat
        public var placeholderColor: UIColor
        public var maxWidth: CGFloat
        public var placeholderHeight: CGFloat
        public static let `default` = ImageStyle(cornerRadius: 8.0, placeholderColor: .secondarySystemBackground, maxWidth: 300.0, placeholderHeight: 200)
        public init(cornerRadius: CGFloat = Self.default.cornerRadius, placeholderColor: UIColor = Self.default.placeholderColor,
                     maxWidth: CGFloat = Self.default.maxWidth, placeholderHeight: CGFloat = Self.default.placeholderHeight) {
            self.cornerRadius = cornerRadius; self.placeholderColor = placeholderColor
            self.maxWidth = maxWidth; self.placeholderHeight = placeholderHeight
        }
    }
}

// MARK: - SpacingStyle

public extension MarkdownTheme {
    struct SpacingStyle {
        public var paragraph: CGFloat
        public var headingBefore: [CGFloat]
        public var headingAfter: CGFloat
        public var listItem: CGFloat
        public var blockQuoteBetween: CGFloat
        public var blockQuoteOther: CGFloat

        public static let `default` = SpacingStyle(
            paragraph: 12.0, headingBefore: [16, 14, 12, 10, 8, 8],
            headingAfter: 8.0, listItem: 4.0, blockQuoteBetween: 0, blockQuoteOther: 8.0
        )

        public init(paragraph: CGFloat = Self.default.paragraph, headingBefore: [CGFloat] = Self.default.headingBefore,
                     headingAfter: CGFloat = Self.default.headingAfter, listItem: CGFloat = Self.default.listItem,
                     blockQuoteBetween: CGFloat = Self.default.blockQuoteBetween, blockQuoteOther: CGFloat = Self.default.blockQuoteOther) {
            self.paragraph = paragraph; self.headingBefore = headingBefore; self.headingAfter = headingAfter
            self.listItem = listItem; self.blockQuoteBetween = blockQuoteBetween; self.blockQuoteOther = blockQuoteOther
        }

        public func headingSpacingBefore(for level: Int) -> CGFloat {
            let i = max(0, min(level - 1, 5))
            return headingBefore[safe: i] ?? headingBefore[0]
        }
    }
}

// MARK: - EmphasisStyle

public extension MarkdownTheme {
    struct EmphasisStyle {
        public var type: EmphasisType
        public var highlightColor: UIColor
        public enum EmphasisType { case italic, highlight, both }
        public static let `default` = EmphasisStyle(type: .italic, highlightColor: UIColor.systemYellow.withAlphaComponent(0.3))
        public init(type: EmphasisType = Self.default.type, highlightColor: UIColor = Self.default.highlightColor) {
            self.type = type; self.highlightColor = highlightColor
        }
    }
}

// MARK: - StrikethroughStyle

public extension MarkdownTheme {
    struct StrikethroughStyle {
        public var style: NSUnderlineStyle
        public var color: UIColor?
        public static let `default` = StrikethroughStyle(style: .single, color: nil)
        public init(style: NSUnderlineStyle = Self.default.style, color: UIColor? = Self.default.color) {
            self.style = style; self.color = color
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
