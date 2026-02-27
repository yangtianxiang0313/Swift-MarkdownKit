//
//  BlockQuoteTextView.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

// MARK: - BlockQuoteTextView

/// 带引用块竖线的文本视图
/// 左侧绘制竖线，右侧显示文本内容
public final class BlockQuoteTextView: UIView, StreamableContent {

    // MARK: - StreamableContent

    public var displayedLength: Int { _revealStrategy.displayedLength }
    public var totalLength: Int { _revealStrategy.totalLength }
    public func reveal(upTo length: Int) { _revealStrategy.reveal(upTo: length) }
    public func updateContent(_ content: Any) -> ContentUpdateResult {
        guard let newText = content as? NSAttributedString else { return .unchanged(length: totalLength) }
        return _revealStrategy.updateContent(newText)
    }
    public var enterAnimationConfig: EnterAnimationConfig? { .default }

    private var _revealStrategy: TextRevealStrategy!

    // MARK: - Subviews
    
    /// 文本视图
    public let textView: UITextView = {
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
    
    /// 竖线视图数组
    private var lineViews: [UIView] = []
    
    // MARK: - State
    
    /// 当前引用深度
    public private(set) var blockQuoteDepth: Int = 0
    
    /// 当前主题
    private var theme: MarkdownTheme = .default
    
    // MARK: - Computed Properties (from theme)
    
    private var barStyle: MarkdownTheme.BlockQuoteBarStyle { theme.blockQuote.bar }
    private var blockQuoteStyle: MarkdownTheme.BlockQuoteStyle { theme.blockQuote }
    
    private var lineColor: UIColor { barStyle.color }
    private var lineWidth: CGFloat { barStyle.width }
    private var lineSpacing: CGFloat { barStyle.spacing }
    private var depthSpacing: CGFloat { blockQuoteStyle.depthSpacing }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        _revealStrategy = SubstringRevealStrategy(targetView: textView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        _revealStrategy = SubstringRevealStrategy(targetView: textView)
    }

    private func setup() {
        addSubview(textView)
    }
    
    // MARK: - Configuration
    
    /// 配置视图
    public func configure(
        attributedString: NSAttributedString,
        blockQuoteDepth: Int,
        theme: MarkdownTheme
    ) {
        self.theme = theme
        self.blockQuoteDepth = blockQuoteDepth
        
        textView.attributedText = attributedString
        
        updateLineViews()
    }
    
    private func updateLineViews() {
        // 移除多余的竖线
        while lineViews.count > blockQuoteDepth {
            lineViews.removeLast().removeFromSuperview()
        }
        
        // 添加需要的竖线
        while lineViews.count < blockQuoteDepth {
            let line = UIView()
            line.backgroundColor = lineColor
            line.layer.cornerRadius = lineWidth / 2
            addSubview(line)
            lineViews.append(line)
        }
        
        // 更新所有竖线样式
        lineViews.forEach { line in
            line.backgroundColor = lineColor
            line.layer.cornerRadius = lineWidth / 2
        }
        
        setNeedsLayout()
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // 计算竖线占用的总宽度
        let totalLineWidth = CGFloat(blockQuoteDepth) * (lineWidth + depthSpacing)
        
        // 布局竖线
        for (index, line) in lineViews.enumerated() {
            let x = CGFloat(index) * (lineWidth + depthSpacing)
            line.frame = CGRect(
                x: x,
                y: 0,
                width: lineWidth,
                height: bounds.height
            )
        }
        
        // 布局文本
        let textX = blockQuoteDepth > 0 ? totalLineWidth : 0
        textView.frame = CGRect(
            x: textX,
            y: 0,
            width: bounds.width - textX,
            height: bounds.height
        )
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let totalLineWidth = CGFloat(blockQuoteDepth) * (lineWidth + depthSpacing)
        let textWidth = size.width - totalLineWidth
        let textSize = textView.sizeThatFits(CGSize(width: textWidth, height: size.height))
        return CGSize(width: size.width, height: textSize.height)
    }

    // MARK: - 静态高度计算（支持动画进度）

    /// 按显示进度计算预估高度
    public static func estimatedHeight(
        attributedString: NSAttributedString,
        displayedLength: Int,
        blockQuoteDepth: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        let barStyle = theme.blockQuote.bar
        let depthSpacing = theme.blockQuote.depthSpacing
        let totalLineWidth = CGFloat(blockQuoteDepth) * (barStyle.width + depthSpacing)
        let textWidth = maxWidth - totalLineWidth

        let len = attributedString.length
        if displayedLength <= 0 {
            return theme.body.lineHeight
        }
        let safeLen = min(displayedLength, len)
        let substring = attributedString.attributedSubstring(from: NSRange(location: 0, length: safeLen))
        let size = substring.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        return ceil(size.height)
    }
}
