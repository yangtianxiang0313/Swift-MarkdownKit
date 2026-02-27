import Foundation
import UIKit

// MARK: - ThematicBreakView

/// 分割线视图
public final class ThematicBreakView: UIView, FragmentConfigurable, StreamableContent, SimpleStreamableContent {

    public var totalLength: Int { 0 }
    
    // MARK: - UI Elements
    
    private let lineView = UIView()
    
    // MARK: - State
    
    private var theme: MarkdownTheme = .default
    
    // MARK: - Computed Properties (from theme)
    
    private var breakStyle: MarkdownTheme.ThematicBreakStyle { theme.thematicBreak }
    private var lineHeight: CGFloat { breakStyle.height }
    private var verticalPadding: CGFloat { breakStyle.verticalPadding }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(lineView)
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        lineView.frame = CGRect(
            x: 0,
            y: verticalPadding,
            width: bounds.width,
            height: lineHeight
        )
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: lineHeight + verticalPadding * 2)
    }
    
    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: lineHeight + verticalPadding * 2)
    }
    
    // MARK: - 静态高度计算

    /// 预估高度（displayedLength 无意义，固定高度）
    public static func estimatedHeight(
        displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        let breakStyle = theme.thematicBreak
        return breakStyle.height + breakStyle.verticalPadding * 2
    }

    // MARK: - FragmentConfigurable

    public func configure(content: Any, theme: MarkdownTheme) {
        // ThematicBreak 没有内容，忽略 content 参数
        self.theme = theme
        lineView.backgroundColor = breakStyle.color
        setNeedsLayout()
    }
}
