import Foundation
import UIKit

// MARK: - TextFragment

/// 文本片段
/// 包含富文本内容，由 Renderer 根据 blockQuoteDepth 提供 makeView 和 configure（方案 1：Fragment 统一携带 ViewFactory）
public struct TextFragment: RenderFragment, FragmentViewFactory, FragmentContextRequirements {
    
    // MARK: - RenderFragment
    
    public let fragmentId: String
    public let nodeType: MarkdownNodeType
    
    // MARK: - Content
    
    /// 富文本内容
    public let attributedString: NSAttributedString
    
    /// 上下文信息（indent、blockQuoteDepth 等）
    public let context: FragmentContext
    
    // MARK: - FragmentViewFactory

    public let reuseIdentifier: ReuseIdentifier
    public let estimatedSize: CGSize
    private let _heightProvider: FragmentHeightProvider?
    private let _makeView: () -> UIView
    private let _configure: (UIView, MarkdownTheme) -> Void

    public func makeView() -> UIView { _makeView() }
    public func configure(_ view: UIView, theme: MarkdownTheme) { _configure(view, theme) }

    public func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        _heightProvider?.estimatedHeight(atDisplayedLength: displayedLength, maxWidth: maxWidth, theme: theme) ?? estimatedSize.height
    }

    // MARK: - Initialization

    public init(
        fragmentId: String,
        nodeType: MarkdownNodeType,
        attributedString: NSAttributedString,
        context: FragmentContext,
        reuseIdentifier: ReuseIdentifier,
        estimatedSize: CGSize,
        heightProvider: FragmentHeightProvider? = nil,
        makeView: @escaping () -> UIView,
        configure: @escaping (UIView, MarkdownTheme) -> Void
    ) {
        self.fragmentId = fragmentId
        self.nodeType = nodeType
        self.attributedString = attributedString
        self.context = context
        self.reuseIdentifier = reuseIdentifier
        self.estimatedSize = estimatedSize
        self._heightProvider = heightProvider
        self._makeView = makeView
        self._configure = configure
    }
}

// MARK: - FragmentContextRequirements

extension TextFragment {
    public static var contextKeys: Set<FragmentContextKey> { [.indent, .blockQuoteDepth] }
}

// MARK: - TextFragment Factory

extension TextFragment {
    
    /// 创建文本 Fragment，根据 blockQuoteDepth 自动选择 View 类型
    /// - Parameter context: 从 `FragmentContext.from(renderContext, for: TextFragment.self)` 自动提取
    public static func create(
        fragmentId: String,
        nodeType: MarkdownNodeType,
        attributedString: NSAttributedString,
        context: FragmentContext,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> TextFragment {
        let indent = context.indent
        let blockQuoteDepth = context.blockQuoteDepth
        let descriptor = TextFragmentViewDescriptor.make(
            attributedString: attributedString,
            blockQuoteDepth: blockQuoteDepth
        )
        let estimatedHeight = Self.calculateEstimatedHeight(
            attributedString: attributedString,
            blockQuoteDepth: blockQuoteDepth,
            maxWidth: maxWidth,
            theme: theme
        )
        let estimatedSize = CGSize(width: maxWidth - indent, height: estimatedHeight)
        let heightProvider = TextHeightProvider(attributedString: attributedString, blockQuoteDepth: blockQuoteDepth)

        return TextFragment(
            fragmentId: fragmentId,
            nodeType: nodeType,
            attributedString: attributedString,
            context: context,
            reuseIdentifier: descriptor.reuseIdentifier,
            estimatedSize: estimatedSize,
            heightProvider: heightProvider,
            makeView: descriptor.makeView,
            configure: descriptor.configure
        )
    }
    
    fileprivate static func createPlainTextView() -> UIView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = TextViewConstants.lineFragmentPadding
        textView.backgroundColor = .clear
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        return textView
    }
}

extension TextFragment {
    private static func calculateEstimatedHeight(
        attributedString: NSAttributedString,
        blockQuoteDepth: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        var textWidth = maxWidth
        if blockQuoteDepth > 0 {
            let barStyle = theme.blockQuote.bar
            let depthSpacing = theme.blockQuote.depthSpacing
            textWidth -= CGFloat(blockQuoteDepth) * (barStyle.width + depthSpacing)
        }
        let size = attributedString.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        return ceil(size.height)
    }
}

// MARK: - TextFragmentViewDescriptor（抽象 View 类型选择，减少 create 重复）

private struct TextFragmentViewDescriptor {
    let reuseIdentifier: ReuseIdentifier
    let makeView: () -> UIView
    let configure: (UIView, MarkdownTheme) -> Void
    
    static func make(
        attributedString: NSAttributedString,
        blockQuoteDepth: Int
    ) -> TextFragmentViewDescriptor {
        if blockQuoteDepth > 0 {
            return TextFragmentViewDescriptor(
                reuseIdentifier: .blockQuoteText,
                makeView: { BlockQuoteTextView() },
                configure: { view, theme in
                    (view as? BlockQuoteTextView)?.configure(
                        attributedString: attributedString,
                        blockQuoteDepth: blockQuoteDepth,
                        theme: theme
                    )
                }
            )
        } else {
            return TextFragmentViewDescriptor(
                reuseIdentifier: .textView,
                makeView: { TextFragment.createPlainTextView() },
                configure: { view, _ in
                    if let tv = view as? UITextView {
                        tv.attributedText = attributedString
                    } else if let label = view as? UILabel {
                        label.attributedText = attributedString
                    }
                }
            )
        }
    }
}

// MARK: - Convenience

extension TextFragment {
    /// 文本长度
    public var length: Int {
        attributedString.length
    }
    
    /// 纯文本
    public var plainText: String {
        attributedString.string
    }
    
    /// 是否为空
    public var isEmpty: Bool {
        attributedString.length == 0
    }
}
