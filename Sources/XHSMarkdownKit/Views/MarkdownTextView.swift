//
//  MarkdownTextView.swift
//  XHSMarkdownKit
//
//  支持流式动画的文本视图，包装 UITextView 实现 StreamableContent
//

import UIKit

// MARK: - MarkdownTextView

/// 支持流式动画的 Markdown 文本视图
/// - 使用 UITextView 承载富文本，支持链接点击
/// - 实现 StreamableContent，通过 TextRevealStrategy 控制逐字揭示
public final class MarkdownTextView: UIView, StreamableContent {

    // MARK: - StreamableContent

    public var displayedLength: Int { _revealStrategy.displayedLength }
    public var totalLength: Int { _revealStrategy.totalLength }
    public func reveal(upTo length: Int) { _revealStrategy.reveal(upTo: length) }
    public func updateContent(_ content: Any) -> ContentUpdateResult {
        guard let newText = content as? NSAttributedString else {
            return .unchanged(length: _revealStrategy.totalLength)
        }
        return _revealStrategy.updateContent(newText)
    }
    public var enterAnimationConfig: EnterAnimationConfig? { .default }

    // MARK: - UI

    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = TextViewConstants.lineFragmentPadding
        tv.backgroundColor = .clear
        tv.isSelectable = true
        tv.dataDetectorTypes = []
        return tv
    }()

    private var _revealStrategy: TextRevealStrategy!

    // MARK: - Initialization

    /// 创建 MarkdownTextView
    /// - Parameters:
    ///   - revealStrategy: 揭示策略，nil 时使用 SubstringRevealStrategy
    ///   - revealStrategyProvider: 策略提供者，用于 makeStrategy(for: textView)
    public init(
        revealStrategy: TextRevealStrategy? = nil,
        revealStrategyProvider: TextRevealStrategyProvider? = nil
    ) {
        super.init(frame: .zero)
        addSubview(textView)
        _revealStrategy = revealStrategy
            ?? revealStrategyProvider?.makeStrategy(for: textView)
            ?? SubstringRevealStrategy(targetView: textView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(textView)
        _revealStrategy = SubstringRevealStrategy(targetView: textView)
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
    }

    // MARK: - 静态高度计算（支持动画进度）

    /// 按显示进度计算预估高度
    /// - Parameters:
    ///   - attributedString: 完整富文本
    ///   - displayedLength: 已显示字符数（0 表示未显示；>= length 表示完整显示）
    ///   - maxWidth: 可用宽度
    ///   - theme: 主题
    /// - Returns: 预估高度
    public static func estimatedHeight(
        attributedString: NSAttributedString,
        displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        let len = attributedString.length
        if displayedLength <= 0 {
            return theme.body.lineHeight
        }
        let safeLen = min(displayedLength, len)
        let substring = attributedString.attributedSubstring(from: NSRange(location: 0, length: safeLen))
        let size = substring.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        return ceil(size.height)
    }
}
