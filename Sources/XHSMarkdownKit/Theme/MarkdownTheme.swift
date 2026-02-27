//
//  MarkdownTheme.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

// MARK: - MarkdownTheme（主题根结构）

/// Markdown 样式主题
/// 采用分层嵌套结构，每个组件有独立的配置子结构
public struct MarkdownTheme {
    
    public static let `default` = MarkdownTheme()
    
    // MARK: - 分层配置
    
    /// 正文样式
    public var body: BodyStyle = .default
    
    /// 标题样式（H1-H6）
    public var heading: HeadingStyle = .default
    
    /// 代码样式（行内代码 + 代码块）
    public var code: CodeStyle = .default
    
    /// 引用块样式
    public var blockQuote: BlockQuoteStyle = .default
    
    /// 链接样式
    public var link: LinkStyle = .default
    
    /// 列表样式
    public var list: ListStyle = .default
    
    /// 表格样式
    public var table: TableStyle = .default
    
    /// 分隔线样式
    public var thematicBreak: ThematicBreakStyle = .default
    
    /// 图片样式
    public var image: ImageStyle = .default
    
    /// 间距配置
    public var spacing: SpacingStyle = .default
    
    /// 动画配置
    public var animation: AnimationStyle = .default
    
    /// 强调样式
    public var emphasis: EmphasisStyle = .default
    
    /// 删除线样式
    public var strikethrough: StrikethroughStyle = .default
    
    // MARK: - 构造器
    public init() {}
}

// MARK: - BodyStyle（正文样式）

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
        
        public init(
            font: UIFont = Self.default.font,
            color: UIColor = Self.default.color,
            lineHeight: CGFloat = Self.default.lineHeight,
            letterSpacing: CGFloat = Self.default.letterSpacing
        ) {
            self.font = font
            self.color = color
            self.lineHeight = lineHeight
            self.letterSpacing = letterSpacing
        }
    }
}

// MARK: - HeadingStyle（标题样式）

public extension MarkdownTheme {
    struct HeadingStyle {
        /// 各级标题字号（H1-H6）
        public var fontSizes: [CGFloat]
        /// 各级标题字重
        public var fontWeights: [UIFont.Weight]
        /// 各级标题行高
        public var lineHeights: [CGFloat]
        /// 默认颜色
        public var color: UIColor
        /// 各级标题颜色（nil 表示使用 color）
        public var colors: [UIColor?]
        
        public static let `default` = HeadingStyle(
            fontSizes: [16, 16, 16, 16, 16, 16],
            fontWeights: [.semibold, .semibold, .semibold, .semibold, .semibold, .semibold],
            lineHeights: [26, 26, 26, 26, 26, 26],
            color: .label,
            colors: [nil, nil, nil, nil, nil, nil]
        )
        
        public init(
            fontSizes: [CGFloat] = Self.default.fontSizes,
            fontWeights: [UIFont.Weight] = Self.default.fontWeights,
            lineHeights: [CGFloat] = Self.default.lineHeights,
            color: UIColor = Self.default.color,
            colors: [UIColor?] = Self.default.colors
        ) {
            self.fontSizes = fontSizes
            self.fontWeights = fontWeights
            self.lineHeights = lineHeights
            self.color = color
            self.colors = colors
        }
        
        /// 获取指定级别的字体
        public func font(for level: Int) -> UIFont {
            let index = max(0, min(level - 1, 5))
            let size = fontSizes[safe: index] ?? fontSizes[0]
            let weight = fontWeights[safe: index] ?? fontWeights[0]
            return .systemFont(ofSize: size, weight: weight)
        }
        
        /// 获取指定级别的颜色
        public func color(for level: Int) -> UIColor {
            let index = max(0, min(level - 1, 5))
            // colors 是 [UIColor?]，所以 colors[safe:] 返回 UIColor??
            // 需要用 flatMap 解包
            return colors[safe: index].flatMap { $0 } ?? color
        }
        
        /// 获取指定级别的行高
        public func lineHeight(for level: Int) -> CGFloat {
            let index = max(0, min(level - 1, 5))
            return lineHeights[safe: index] ?? lineHeights[0]
        }
    }
}

// MARK: - CodeStyle（代码样式）

public extension MarkdownTheme {
    struct CodeStyle {
        /// 代码字体（行内 + 块）
        public var font: UIFont
        /// 行内代码颜色
        public var inlineColor: UIColor
        /// 行内代码背景色
        public var inlineBackgroundColor: UIColor?
        /// 行内代码字间距
        public var letterSpacing: CGFloat
        /// 代码块配置
        public var block: CodeBlockStyle
        
        public static let `default` = CodeStyle(
            font: .monospacedSystemFont(ofSize: 14, weight: .regular),
            inlineColor: .systemGray,
            inlineBackgroundColor: nil,
            letterSpacing: 0,
            block: .default
        )
        
        public init(
            font: UIFont = Self.default.font,
            inlineColor: UIColor = Self.default.inlineColor,
            inlineBackgroundColor: UIColor? = Self.default.inlineBackgroundColor,
            letterSpacing: CGFloat = Self.default.letterSpacing,
            block: CodeBlockStyle = Self.default.block
        ) {
            self.font = font
            self.inlineColor = inlineColor
            self.inlineBackgroundColor = inlineBackgroundColor
            self.letterSpacing = letterSpacing
            self.block = block
        }
    }
    
    struct CodeBlockStyle {
        /// 背景色
        public var backgroundColor: UIColor
        /// 圆角
        public var cornerRadius: CGFloat
        /// 内边距
        public var padding: UIEdgeInsets
        /// 代码区域尺寸计算余量
        public var contentPadding: CGFloat
        /// 边框宽度
        public var borderWidth: CGFloat
        /// 边框颜色
        public var borderColor: UIColor
        /// 最大显示高度（nil = 无限制）
        public var maxDisplayHeight: CGFloat?
        /// Header 配置
        public var header: CodeBlockHeaderStyle
        
        public static let `default` = CodeBlockStyle(
            backgroundColor: .secondarySystemBackground,
            cornerRadius: 10,
            padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
            contentPadding: 2,
            borderWidth: 0.5,
            borderColor: .separator,
            maxDisplayHeight: 300,
            header: .default
        )
        
        public init(
            backgroundColor: UIColor = Self.default.backgroundColor,
            cornerRadius: CGFloat = Self.default.cornerRadius,
            padding: UIEdgeInsets = Self.default.padding,
            contentPadding: CGFloat = Self.default.contentPadding,
            borderWidth: CGFloat = Self.default.borderWidth,
            borderColor: UIColor = Self.default.borderColor,
            maxDisplayHeight: CGFloat? = Self.default.maxDisplayHeight,
            header: CodeBlockHeaderStyle = Self.default.header
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.contentPadding = contentPadding
            self.borderWidth = borderWidth
            self.borderColor = borderColor
            self.maxDisplayHeight = maxDisplayHeight
            self.header = header
        }
    }
    
    struct CodeBlockHeaderStyle {
        /// Header 高度
        public var height: CGFloat
        /// Header 背景变暗比例
        public var darkenRatio: CGFloat
        /// 分隔线高度
        public var separatorHeight: CGFloat
        /// 语言 Badge 配置
        public var badge: BadgeStyle
        /// 复制按钮配置
        public var copyButton: ButtonStyle
        /// 复制成功提示显示时长
        public var copySuccessDuration: TimeInterval
        
        public static let `default` = CodeBlockHeaderStyle(
            height: 36,
            darkenRatio: 0.03,
            separatorHeight: 0.5,
            badge: .default,
            copyButton: .default,
            copySuccessDuration: 1.5
        )
        
        public init(
            height: CGFloat = Self.default.height,
            darkenRatio: CGFloat = Self.default.darkenRatio,
            separatorHeight: CGFloat = Self.default.separatorHeight,
            badge: BadgeStyle = Self.default.badge,
            copyButton: ButtonStyle = Self.default.copyButton,
            copySuccessDuration: TimeInterval = Self.default.copySuccessDuration
        ) {
            self.height = height
            self.darkenRatio = darkenRatio
            self.separatorHeight = separatorHeight
            self.badge = badge
            self.copyButton = copyButton
            self.copySuccessDuration = copySuccessDuration
        }
    }
    
    struct BadgeStyle {
        public var font: UIFont
        public var textColor: UIColor
        public var backgroundColor: UIColor
        public var cornerRadius: CGFloat
        public var height: CGFloat
        public var horizontalPadding: CGFloat
        
        public static let `default` = BadgeStyle(
            font: .systemFont(ofSize: 11, weight: .medium),
            textColor: .secondaryLabel,
            backgroundColor: .systemGray5,
            cornerRadius: 4,
            height: 20,
            horizontalPadding: 6
        )
        
        public init(
            font: UIFont = Self.default.font,
            textColor: UIColor = Self.default.textColor,
            backgroundColor: UIColor = Self.default.backgroundColor,
            cornerRadius: CGFloat = Self.default.cornerRadius,
            height: CGFloat = Self.default.height,
            horizontalPadding: CGFloat = Self.default.horizontalPadding
        ) {
            self.font = font
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.height = height
            self.horizontalPadding = horizontalPadding
        }
    }
    
    struct ButtonStyle {
        public var font: UIFont
        public var textColor: UIColor
        public var backgroundColor: UIColor
        public var cornerRadius: CGFloat
        public var contentInsets: UIEdgeInsets
        public var height: CGFloat
        public var horizontalPadding: CGFloat
        /// 点击时的缩放比例
        public var pressedScale: CGFloat
        /// 点击动画时长
        public var pressedAnimationDuration: TimeInterval
        /// 复制按钮文案
        public var copyTitle: String
        /// 复制按钮图标 SF Symbol
        public var copyIconName: String
        /// 图标尺寸
        public var iconPointSize: CGFloat
        /// 复制成功反馈文案
        public var copiedTitle: String
        /// 复制成功图标
        public var copiedIconName: String
        /// 复制成功后的文本颜色
        public var copiedTextColor: UIColor
        
        public static let `default` = ButtonStyle(
            font: .systemFont(ofSize: 11, weight: .medium),
            textColor: .secondaryLabel,
            backgroundColor: .systemGray5,
            cornerRadius: 4,
            contentInsets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8),
            height: 24,
            horizontalPadding: 8,
            pressedScale: 0.95,
            pressedAnimationDuration: 0.1,
            copyTitle: "复制",
            copyIconName: "doc.on.doc",
            iconPointSize: 11,
            copiedTitle: "已复制",
            copiedIconName: "checkmark",
            copiedTextColor: .systemGreen
        )
        
        public init(
            font: UIFont = Self.default.font,
            textColor: UIColor = Self.default.textColor,
            backgroundColor: UIColor = Self.default.backgroundColor,
            cornerRadius: CGFloat = Self.default.cornerRadius,
            contentInsets: UIEdgeInsets = Self.default.contentInsets,
            height: CGFloat = Self.default.height,
            horizontalPadding: CGFloat = Self.default.horizontalPadding,
            pressedScale: CGFloat = Self.default.pressedScale,
            pressedAnimationDuration: TimeInterval = Self.default.pressedAnimationDuration,
            copyTitle: String = Self.default.copyTitle,
            copyIconName: String = Self.default.copyIconName,
            iconPointSize: CGFloat = Self.default.iconPointSize,
            copiedTitle: String = Self.default.copiedTitle,
            copiedIconName: String = Self.default.copiedIconName,
            copiedTextColor: UIColor = Self.default.copiedTextColor
        ) {
            self.font = font
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.contentInsets = contentInsets
            self.height = height
            self.horizontalPadding = horizontalPadding
            self.pressedScale = pressedScale
            self.pressedAnimationDuration = pressedAnimationDuration
            self.copyTitle = copyTitle
            self.copyIconName = copyIconName
            self.iconPointSize = iconPointSize
            self.copiedTitle = copiedTitle
            self.copiedIconName = copiedIconName
            self.copiedTextColor = copiedTextColor
        }
    }
}

// MARK: - BlockQuoteStyle（引用块样式）

public extension MarkdownTheme {
    struct BlockQuoteStyle {
        public var font: UIFont
        public var textColor: UIColor
        public var lineHeight: CGFloat
        /// 左侧竖线配置
        public var bar: BlockQuoteBarStyle
        /// 每层嵌套增加的缩进
        public var nestingIndent: CGFloat
        /// 每层嵌套间的间距
        public var depthSpacing: CGFloat
        
        public static let `default` = BlockQuoteStyle(
            font: .systemFont(ofSize: 15, weight: .regular),
            textColor: .label,
            lineHeight: 25.0,
            bar: .default,
            nestingIndent: 20.0,
            depthSpacing: 12.0
        )
        
        public init(
            font: UIFont = Self.default.font,
            textColor: UIColor = Self.default.textColor,
            lineHeight: CGFloat = Self.default.lineHeight,
            bar: BlockQuoteBarStyle = Self.default.bar,
            nestingIndent: CGFloat = Self.default.nestingIndent,
            depthSpacing: CGFloat = Self.default.depthSpacing
        ) {
            self.font = font
            self.textColor = textColor
            self.lineHeight = lineHeight
            self.bar = bar
            self.nestingIndent = nestingIndent
            self.depthSpacing = depthSpacing
        }
    }
    
    struct BlockQuoteBarStyle {
        public var color: UIColor
        public var width: CGFloat
        public var leftMargin: CGFloat
        /// 竖线之间的间距
        public var spacing: CGFloat
        
        public static let `default` = BlockQuoteBarStyle(
            color: .separator,
            width: 3.0,
            leftMargin: 8.0,
            spacing: 8.0
        )
        
        public init(
            color: UIColor = Self.default.color,
            width: CGFloat = Self.default.width,
            leftMargin: CGFloat = Self.default.leftMargin,
            spacing: CGFloat = Self.default.spacing
        ) {
            self.color = color
            self.width = width
            self.leftMargin = leftMargin
            self.spacing = spacing
        }
    }
}

// MARK: - LinkStyle（链接样式）

public extension MarkdownTheme {
    struct LinkStyle {
        public var color: UIColor
        public var underlineStyle: NSUnderlineStyle
        
        public static let `default` = LinkStyle(
            color: .systemBlue,
            underlineStyle: []
        )
        
        public init(
            color: UIColor = Self.default.color,
            underlineStyle: NSUnderlineStyle = Self.default.underlineStyle
        ) {
            self.color = color
            self.underlineStyle = underlineStyle
        }
    }
}

// MARK: - ListStyle（列表样式）

public extension MarkdownTheme {
    struct ListStyle {
        /// 无序列表配置
        public var unordered: UnorderedListStyle
        /// 有序列表配置
        public var ordered: OrderedListStyle
        /// 每层嵌套增加的缩进
        public var nestingIndent: CGFloat
        
        public static let `default` = ListStyle(
            unordered: .default,
            ordered: .default,
            nestingIndent: 20.0
        )
        
        public init(
            unordered: UnorderedListStyle = Self.default.unordered,
            ordered: OrderedListStyle = Self.default.ordered,
            nestingIndent: CGFloat = Self.default.nestingIndent
        ) {
            self.unordered = unordered
            self.ordered = ordered
            self.nestingIndent = nestingIndent
        }
    }
    
    struct UnorderedListStyle {
        /// 项目符号（默认）
        public var symbol: String
        /// 各层级符号（depth=1 用 [0]，depth=2 用 [1]...）
        public var symbols: [String]
        public var symbolFont: UIFont
        public var symbolColor: UIColor
        public var symbolLeftMargin: CGFloat
        public var symbolRightMargin: CGFloat
        
        public static let `default` = UnorderedListStyle(
            symbol: "•",
            symbols: ["-", "◦", "▪"],
            symbolFont: .systemFont(ofSize: 15, weight: .black),
            symbolColor: .placeholderText,
            symbolLeftMargin: 5.0,
            symbolRightMargin: 11.0
        )
        
        public init(
            symbol: String = Self.default.symbol,
            symbols: [String] = Self.default.symbols,
            symbolFont: UIFont = Self.default.symbolFont,
            symbolColor: UIColor = Self.default.symbolColor,
            symbolLeftMargin: CGFloat = Self.default.symbolLeftMargin,
            symbolRightMargin: CGFloat = Self.default.symbolRightMargin
        ) {
            self.symbol = symbol
            self.symbols = symbols
            self.symbolFont = symbolFont
            self.symbolColor = symbolColor
            self.symbolLeftMargin = symbolLeftMargin
            self.symbolRightMargin = symbolRightMargin
        }
        
        /// 获取指定深度的符号
        public func symbol(for depth: Int) -> String {
            let index = max(0, depth - 1) % symbols.count
            return symbols[safe: index] ?? symbol
        }
    }
    
    struct OrderedListStyle {
        public var numberFont: UIFont
        public var numberColor: UIColor
        public var numberLeftMargin: CGFloat
        public var textLeftMargin: CGFloat
        public var alignToEdge: Bool
        
        public static let `default` = OrderedListStyle(
            numberFont: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            numberColor: .placeholderText,
            numberLeftMargin: 4.0,
            textLeftMargin: 22.0,
            alignToEdge: true
        )
        
        public init(
            numberFont: UIFont = Self.default.numberFont,
            numberColor: UIColor = Self.default.numberColor,
            numberLeftMargin: CGFloat = Self.default.numberLeftMargin,
            textLeftMargin: CGFloat = Self.default.textLeftMargin,
            alignToEdge: Bool = Self.default.alignToEdge
        ) {
            self.numberFont = numberFont
            self.numberColor = numberColor
            self.numberLeftMargin = numberLeftMargin
            self.textLeftMargin = textLeftMargin
            self.alignToEdge = alignToEdge
        }
    }
}

// MARK: - TableStyle（表格样式）

public extension MarkdownTheme {
    struct TableStyle {
        public var font: UIFont
        public var textColor: UIColor
        public var headerFont: UIFont
        public var headerTextColor: UIColor
        public var headerBackgroundColor: UIColor
        public var cellBackgroundColor: UIColor
        public var borderColor: UIColor
        public var borderWidth: CGFloat
        public var cornerRadius: CGFloat
        public var cellPadding: UIEdgeInsets
        public var minColumnWidth: CGFloat
        public var maxColumnWidth: CGFloat
        public var minRowHeight: CGFloat
        public var maxDisplayHeight: CGFloat?
        /// 空表格/错误状态的默认高度
        public var defaultHeight: CGFloat
        
        public static let `default` = TableStyle(
            font: .systemFont(ofSize: 14),
            textColor: .label,
            headerFont: .systemFont(ofSize: 14, weight: .semibold),
            headerTextColor: .label,
            headerBackgroundColor: .secondarySystemBackground,
            cellBackgroundColor: .clear,
            borderColor: .separator,
            borderWidth: 1.0,
            cornerRadius: 8.0,
            cellPadding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12),
            minColumnWidth: 60,
            maxColumnWidth: 200,
            minRowHeight: 36,
            maxDisplayHeight: 400,
            defaultHeight: 44
        )
        
        public init(
            font: UIFont = Self.default.font,
            textColor: UIColor = Self.default.textColor,
            headerFont: UIFont = Self.default.headerFont,
            headerTextColor: UIColor = Self.default.headerTextColor,
            headerBackgroundColor: UIColor = Self.default.headerBackgroundColor,
            cellBackgroundColor: UIColor = Self.default.cellBackgroundColor,
            borderColor: UIColor = Self.default.borderColor,
            borderWidth: CGFloat = Self.default.borderWidth,
            cornerRadius: CGFloat = Self.default.cornerRadius,
            cellPadding: UIEdgeInsets = Self.default.cellPadding,
            minColumnWidth: CGFloat = Self.default.minColumnWidth,
            maxColumnWidth: CGFloat = Self.default.maxColumnWidth,
            minRowHeight: CGFloat = Self.default.minRowHeight,
            maxDisplayHeight: CGFloat? = Self.default.maxDisplayHeight,
            defaultHeight: CGFloat = Self.default.defaultHeight
        ) {
            self.font = font
            self.textColor = textColor
            self.headerFont = headerFont
            self.headerTextColor = headerTextColor
            self.headerBackgroundColor = headerBackgroundColor
            self.cellBackgroundColor = cellBackgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.cornerRadius = cornerRadius
            self.cellPadding = cellPadding
            self.minColumnWidth = minColumnWidth
            self.maxColumnWidth = maxColumnWidth
            self.minRowHeight = minRowHeight
            self.maxDisplayHeight = maxDisplayHeight
            self.defaultHeight = defaultHeight
        }
    }
}

// MARK: - ThematicBreakStyle（分隔线样式）

public extension MarkdownTheme {
    struct ThematicBreakStyle {
        public var color: UIColor
        public var height: CGFloat
        public var verticalPadding: CGFloat
        
        public static let `default` = ThematicBreakStyle(
            color: UIColor.black.withAlphaComponent(0.05),
            height: 1.0,
            verticalPadding: 7.5
        )
        
        public init(
            color: UIColor = Self.default.color,
            height: CGFloat = Self.default.height,
            verticalPadding: CGFloat = Self.default.verticalPadding
        ) {
            self.color = color
            self.height = height
            self.verticalPadding = verticalPadding
        }
    }
}

// MARK: - ImageStyle（图片样式）

public extension MarkdownTheme {
    struct ImageStyle {
        public var cornerRadius: CGFloat
        public var placeholderColor: UIColor
        public var maxWidth: CGFloat
        /// 加载中占位高度
        public var placeholderHeight: CGFloat
        
        public static let `default` = ImageStyle(
            cornerRadius: 8.0,
            placeholderColor: .secondarySystemBackground,
            maxWidth: 300.0,
            placeholderHeight: 200
        )
        
        public init(
            cornerRadius: CGFloat = Self.default.cornerRadius,
            placeholderColor: UIColor = Self.default.placeholderColor,
            maxWidth: CGFloat = Self.default.maxWidth,
            placeholderHeight: CGFloat = Self.default.placeholderHeight
        ) {
            self.cornerRadius = cornerRadius
            self.placeholderColor = placeholderColor
            self.maxWidth = maxWidth
            self.placeholderHeight = placeholderHeight
        }
    }
}

// MARK: - SpacingStyle（间距配置）

public extension MarkdownTheme {
    struct SpacingStyle {
        /// 段落间距
        public var paragraph: CGFloat
        /// 各级标题前间距
        public var headingBefore: [CGFloat]
        /// 标题后间距
        public var headingAfter: CGFloat
        /// 列表项间距
        public var listItem: CGFloat
        /// 文本-列表间距
        public var listAfterText: CGFloat
        /// 段落内间距
        public var innerParagraph: CGFloat
        /// 引用块之间的间距
        public var blockQuoteBetween: CGFloat
        /// 引用块与其他元素间距
        public var blockQuoteOther: CGFloat
        /// Fragment 默认高度
        public var defaultFragmentHeight: CGFloat
        /// 宽度变化阈值（用于判断是否需要重新布局）
        public var widthChangeThreshold: CGFloat
        
        public static let `default` = SpacingStyle(
            paragraph: 12.0,
            headingBefore: [16, 14, 12, 10, 8, 8],
            headingAfter: 8.0,
            listItem: 4.0,
            listAfterText: 8.0,
            innerParagraph: 4.0,
            blockQuoteBetween: 4.0,
            blockQuoteOther: 8.0,
            defaultFragmentHeight: 44,
            widthChangeThreshold: 1.0
        )
        
        public init(
            paragraph: CGFloat = Self.default.paragraph,
            headingBefore: [CGFloat] = Self.default.headingBefore,
            headingAfter: CGFloat = Self.default.headingAfter,
            listItem: CGFloat = Self.default.listItem,
            listAfterText: CGFloat = Self.default.listAfterText,
            innerParagraph: CGFloat = Self.default.innerParagraph,
            blockQuoteBetween: CGFloat = Self.default.blockQuoteBetween,
            blockQuoteOther: CGFloat = Self.default.blockQuoteOther,
            defaultFragmentHeight: CGFloat = Self.default.defaultFragmentHeight,
            widthChangeThreshold: CGFloat = Self.default.widthChangeThreshold
        ) {
            self.paragraph = paragraph
            self.headingBefore = headingBefore
            self.headingAfter = headingAfter
            self.listItem = listItem
            self.listAfterText = listAfterText
            self.innerParagraph = innerParagraph
            self.blockQuoteBetween = blockQuoteBetween
            self.blockQuoteOther = blockQuoteOther
            self.defaultFragmentHeight = defaultFragmentHeight
            self.widthChangeThreshold = widthChangeThreshold
        }
        
        /// 获取指定级别标题的前间距
        public func headingSpacingBefore(for level: Int) -> CGFloat {
            let index = max(0, min(level - 1, 5))
            return headingBefore[safe: index] ?? headingBefore[0]
        }
    }
}

// MARK: - AnimationStyle（动画配置）

public extension MarkdownTheme {
    struct AnimationStyle {
        /// 布局动画时长
        public var layoutDuration: TimeInterval
        /// 布局动画曲线
        public var layoutCurve: UIView.AnimationOptions
        /// 是否启用动画（全局开关）
        public var isEnabled: Bool
        /// 进入动画配置
        public var enter: EnterAnimation
        /// 退出动画配置
        public var exit: ExitAnimation
        /// 流式动画配置
        public var streaming: StreamingAnimation
        
        public static let `default` = AnimationStyle(
            layoutDuration: 0.15,
            layoutCurve: .curveEaseInOut,
            isEnabled: true,
            enter: .default,
            exit: .default,
            streaming: .default
        )
        
        /// 无动画预设
        public static let none = AnimationStyle(
            layoutDuration: 0,
            isEnabled: false,
            enter: .none,
            exit: .none,
            streaming: .none
        )
        
        /// 快速动画预设
        public static let fast = AnimationStyle(
            layoutDuration: 0.1,
            enter: .fast,
            exit: .fast,
            streaming: .fast
        )
        
        public init(
            layoutDuration: TimeInterval = Self.default.layoutDuration,
            layoutCurve: UIView.AnimationOptions = Self.default.layoutCurve,
            isEnabled: Bool = Self.default.isEnabled,
            enter: EnterAnimation = Self.default.enter,
            exit: ExitAnimation = Self.default.exit,
            streaming: StreamingAnimation = Self.default.streaming
        ) {
            self.layoutDuration = layoutDuration
            self.layoutCurve = layoutCurve
            self.isEnabled = isEnabled
            self.enter = enter
            self.exit = exit
            self.streaming = streaming
        }
    }
    
    /// 进入动画类型
    enum EnterAnimationType {
        /// 淡入
        case fadeIn
        /// 从下滑入
        case slideUp
        /// 弹性缩放
        case spring
        /// 无动画
        case none
        /// 组合动画
        case combined([EnterAnimationType])
    }
    
    struct EnterAnimation {
        /// 动画类型
        public var type: EnterAnimationType
        /// 淡入时长
        public var fadeInDuration: TimeInterval
        /// 上滑偏移量
        public var slideUpOffset: CGFloat
        /// 弹性阻尼
        public var springDamping: CGFloat
        /// 弹性初速度
        public var springVelocity: CGFloat
        /// 缩放比例（弹性动画）
        public var scaleRatio: CGFloat
        /// 弹性动画偏移量系数（相对于 slideUpOffset）
        public var springSlideOffsetRatio: CGFloat
        /// Expand 动画的初始水平缩放
        public var expandInitialScale: CGFloat
        /// 延迟时间
        public var delay: TimeInterval
        /// 是否使用交错动画（多个元素时）
        public var staggered: Bool
        /// 交错间隔时间
        public var staggerInterval: TimeInterval
        
        public static let `default` = EnterAnimation(
            type: .fadeIn,
            fadeInDuration: 0.2,
            slideUpOffset: 20,
            springDamping: 0.7,
            springVelocity: 0.5,
            scaleRatio: 0.9,
            springSlideOffsetRatio: 0.5,
            expandInitialScale: 0.95,
            delay: 0,
            staggered: false,
            staggerInterval: 0.05
        )
        
        /// 无动画
        public static let none = EnterAnimation(
            type: .none,
            fadeInDuration: 0,
            slideUpOffset: 0,
            springSlideOffsetRatio: 0.5,
            expandInitialScale: 0.95,
            delay: 0
        )
        
        /// 快速淡入
        public static let fast = EnterAnimation(
            type: .fadeIn,
            fadeInDuration: 0.1,
            slideUpOffset: 10
        )
        
        /// 弹性动画
        public static let spring = EnterAnimation(
            type: .spring,
            fadeInDuration: 0.3,
            slideUpOffset: 30,
            springDamping: 0.6,
            springVelocity: 0.8,
            scaleRatio: 0.85
        )
        
        /// 滑入动画
        public static let slideUp = EnterAnimation(
            type: .slideUp,
            fadeInDuration: 0.25,
            slideUpOffset: 40
        )
        
        public init(
            type: EnterAnimationType = Self.default.type,
            fadeInDuration: TimeInterval = Self.default.fadeInDuration,
            slideUpOffset: CGFloat = Self.default.slideUpOffset,
            springDamping: CGFloat = Self.default.springDamping,
            springVelocity: CGFloat = Self.default.springVelocity,
            scaleRatio: CGFloat = Self.default.scaleRatio,
            springSlideOffsetRatio: CGFloat = Self.default.springSlideOffsetRatio,
            expandInitialScale: CGFloat = Self.default.expandInitialScale,
            delay: TimeInterval = Self.default.delay,
            staggered: Bool = Self.default.staggered,
            staggerInterval: TimeInterval = Self.default.staggerInterval
        ) {
            self.type = type
            self.fadeInDuration = fadeInDuration
            self.slideUpOffset = slideUpOffset
            self.springDamping = springDamping
            self.springVelocity = springVelocity
            self.scaleRatio = scaleRatio
            self.springSlideOffsetRatio = springSlideOffsetRatio
            self.expandInitialScale = expandInitialScale
            self.delay = delay
            self.staggered = staggered
            self.staggerInterval = staggerInterval
        }
    }
    
    /// 退出动画类型
    enum ExitAnimationType {
        /// 淡出
        case fadeOut
        /// 向下滑出
        case slideDown
        /// 缩小消失
        case scaleDown
        /// 无动画
        case none
    }
    
    struct ExitAnimation {
        /// 动画类型
        public var type: ExitAnimationType
        /// 淡出时长
        public var fadeOutDuration: TimeInterval
        /// 下滑偏移量
        public var slideDownOffset: CGFloat
        /// 缩小比例
        public var scaleRatio: CGFloat
        
        public static let `default` = ExitAnimation(
            type: .fadeOut,
            fadeOutDuration: 0.2,
            slideDownOffset: 20,
            scaleRatio: 0.9
        )
        
        public static let none = ExitAnimation(
            type: .none,
            fadeOutDuration: 0,
            slideDownOffset: 0
        )
        
        public static let fast = ExitAnimation(
            type: .fadeOut,
            fadeOutDuration: 0.1
        )
        
        public init(
            type: ExitAnimationType = Self.default.type,
            fadeOutDuration: TimeInterval = Self.default.fadeOutDuration,
            slideDownOffset: CGFloat = Self.default.slideDownOffset,
            scaleRatio: CGFloat = Self.default.scaleRatio
        ) {
            self.type = type
            self.fadeOutDuration = fadeOutDuration
            self.slideDownOffset = slideDownOffset
            self.scaleRatio = scaleRatio
        }
    }
    
    /// 流式动画模式
    enum StreamingMode {
        /// 逐字打字机效果
        case typewriter
        /// 整段淡入
        case fadeIn
        /// 无动画
        case none
    }
    
    struct StreamingAnimation {
        /// 动画模式
        public var mode: StreamingMode
        /// 基础速度（每帧字符数）
        public var baseCharsPerFrame: Int
        /// 最大速度（每帧字符数上限）
        public var maxCharsPerFrame: Int
        /// 积压阈值配置
        public var thresholds: StreamingThresholds
        /// View 展开动画时长
        public var viewExpandDuration: TimeInterval
        /// View 淡出动画时长
        public var viewFadeOutDuration: TimeInterval
        /// 文本更新动画时长
        public var textUpdateDuration: TimeInterval
        /// DisplayLink 帧率模式
        public var frameRateMode: FrameRateMode
        /// 快进时是否有过渡动画
        public var fastForwardAnimated: Bool
        /// 快进动画时长
        public var fastForwardDuration: TimeInterval
        /// 完成时回调延迟
        public var completionDelay: TimeInterval
        
        public static let `default` = StreamingAnimation(
            mode: .typewriter,
            baseCharsPerFrame: 2,
            maxCharsPerFrame: 20,
            thresholds: .default,
            viewExpandDuration: 0.3,
            viewFadeOutDuration: 0.2,
            textUpdateDuration: 0.15,
            frameRateMode: .default,
            fastForwardAnimated: true,
            fastForwardDuration: 0.2,
            completionDelay: 0
        )
        
        /// 无动画
        public static let none = StreamingAnimation(
            mode: .none,
            baseCharsPerFrame: Int.max,
            maxCharsPerFrame: Int.max,
            viewExpandDuration: 0,
            viewFadeOutDuration: 0,
            textUpdateDuration: 0,
            fastForwardAnimated: false
        )
        
        /// 快速模式
        public static let fast = StreamingAnimation(
            mode: .typewriter,
            baseCharsPerFrame: 4,
            maxCharsPerFrame: 30,
            thresholds: .aggressive,
            viewExpandDuration: 0.15,
            viewFadeOutDuration: 0.1,
            textUpdateDuration: 0.08
        )
        
        /// 慢速模式（适合演示）
        public static let slow = StreamingAnimation(
            mode: .typewriter,
            baseCharsPerFrame: 1,
            maxCharsPerFrame: 5,
            thresholds: .relaxed,
            viewExpandDuration: 0.5,
            viewFadeOutDuration: 0.3,
            textUpdateDuration: 0.2
        )
        
        public init(
            mode: StreamingMode = Self.default.mode,
            baseCharsPerFrame: Int = Self.default.baseCharsPerFrame,
            maxCharsPerFrame: Int = Self.default.maxCharsPerFrame,
            thresholds: StreamingThresholds = Self.default.thresholds,
            viewExpandDuration: TimeInterval = Self.default.viewExpandDuration,
            viewFadeOutDuration: TimeInterval = Self.default.viewFadeOutDuration,
            textUpdateDuration: TimeInterval = Self.default.textUpdateDuration,
            frameRateMode: FrameRateMode = Self.default.frameRateMode,
            fastForwardAnimated: Bool = Self.default.fastForwardAnimated,
            fastForwardDuration: TimeInterval = Self.default.fastForwardDuration,
            completionDelay: TimeInterval = Self.default.completionDelay
        ) {
            self.mode = mode
            self.baseCharsPerFrame = baseCharsPerFrame
            self.maxCharsPerFrame = maxCharsPerFrame
            self.thresholds = thresholds
            self.viewExpandDuration = viewExpandDuration
            self.viewFadeOutDuration = viewFadeOutDuration
            self.textUpdateDuration = textUpdateDuration
            self.frameRateMode = frameRateMode
            self.fastForwardAnimated = fastForwardAnimated
            self.fastForwardDuration = fastForwardDuration
            self.completionDelay = completionDelay
        }
    }
    
    /// DisplayLink 帧率模式
    enum FrameRateMode {
        /// 跟随系统（60Hz/120Hz）
        case `default`
        /// 固定 30fps（省电）
        case low
        /// 固定 60fps
        case normal
        /// ProMotion（120fps，如果支持）
        case high
        
        /// 转换为 preferredFramesPerSecond 值
        public var preferredFramesPerSecond: Int {
            switch self {
            case .default: return 0  // 系统默认
            case .low: return 30
            case .normal: return 60
            case .high: return 120
            }
        }
    }
    
    struct StreamingThresholds {
        /// 阈值 1：开始加速
        public var level1: Int
        /// 阈值 2：中等加速
        public var level2: Int
        /// 阈值 3：快速加速
        public var level3: Int
        /// 阈值 4：极速加速
        public var level4: Int
        /// 各级别对应的加速倍数
        public var multipliers: [Double]
        
        public static let `default` = StreamingThresholds(
            level1: 50,
            level2: 100,
            level3: 200,
            level4: 300,
            multipliers: [1.0, 1.5, 2.0, 3.0, 4.0]
        )
        
        /// 激进模式（更快追赶）
        public static let aggressive = StreamingThresholds(
            level1: 30,
            level2: 60,
            level3: 100,
            level4: 150,
            multipliers: [1.0, 2.0, 3.0, 4.0, 6.0]
        )
        
        /// 宽松模式（更平滑）
        public static let relaxed = StreamingThresholds(
            level1: 100,
            level2: 200,
            level3: 400,
            level4: 600,
            multipliers: [1.0, 1.2, 1.5, 2.0, 2.5]
        )
        
        public init(
            level1: Int = Self.default.level1,
            level2: Int = Self.default.level2,
            level3: Int = Self.default.level3,
            level4: Int = Self.default.level4,
            multipliers: [Double] = Self.default.multipliers
        ) {
            self.level1 = level1
            self.level2 = level2
            self.level3 = level3
            self.level4 = level4
            self.multipliers = multipliers
        }
        
        /// 根据积压量获取加速倍数
        public func multiplier(for queueSize: Int) -> Double {
            switch queueSize {
            case 0..<level1:
                return multipliers[safe: 0] ?? 1.0
            case level1..<level2:
                return multipliers[safe: 1] ?? 1.5
            case level2..<level3:
                return multipliers[safe: 2] ?? 2.0
            case level3..<level4:
                return multipliers[safe: 3] ?? 3.0
            default:
                return multipliers[safe: 4] ?? 4.0
            }
        }
    }
}

// MARK: - EmphasisStyle（强调样式）

public extension MarkdownTheme {
    struct EmphasisStyle {
        public var type: EmphasisType
        public var highlightColor: UIColor
        
        public enum EmphasisType {
            case italic
            case highlight
            case both
        }
        
        public static let `default` = EmphasisStyle(
            type: .italic,
            highlightColor: UIColor.systemYellow.withAlphaComponent(0.3)
        )
        
        public init(
            type: EmphasisType = Self.default.type,
            highlightColor: UIColor = Self.default.highlightColor
        ) {
            self.type = type
            self.highlightColor = highlightColor
        }
    }
}

// MARK: - StrikethroughStyle（删除线样式）

public extension MarkdownTheme {
    struct StrikethroughStyle {
        public var style: NSUnderlineStyle
        /// nil 表示跟随文本颜色
        public var color: UIColor?
        
        public static let `default` = StrikethroughStyle(
            style: .single,
            color: nil
        )
        
        public init(
            style: NSUnderlineStyle = Self.default.style,
            color: UIColor? = Self.default.color
        ) {
            self.style = style
            self.color = color
        }
    }
}

// MARK: - 预设主题

public extension MarkdownTheme {
    /// 富文本主题（适合对话场景）
    static let richtext: MarkdownTheme = {
        var theme = MarkdownTheme()
        theme.body.lineHeight = 25.0
        theme.spacing.paragraph = 26.0
        return theme
    }()
    
    /// 紧凑主题（适合小卡片、预览等）
    static let compact: MarkdownTheme = {
        var theme = MarkdownTheme()
        theme.body = BodyStyle(
            font: .systemFont(ofSize: 14, weight: .regular),
            lineHeight: 22.0
        )
        theme.spacing.paragraph = 16.0
        theme.spacing.headingAfter = 8.0
        theme.spacing.listItem = 4.0
        return theme
    }()
    
    /// 阅读主题（适合文章详情）
    static let readable: MarkdownTheme = {
        var theme = MarkdownTheme()
        theme.body = BodyStyle(
            font: .systemFont(ofSize: 16, weight: .regular),
            lineHeight: 28.0
        )
        theme.spacing.paragraph = 24.0
        theme.heading = HeadingStyle(
            fontSizes: [24, 20, 18, 16, 15, 14],
            lineHeights: [32, 28, 26, 24, 22, 20]
        )
        return theme
    }()
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
