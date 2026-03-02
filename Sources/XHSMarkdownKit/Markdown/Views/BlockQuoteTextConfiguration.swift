import UIKit

/// BlockQuoteTextView 的配置结构体
public struct BlockQuoteTextConfiguration {
    
    // MARK: - 内容
    
    public let attributedString: NSAttributedString
    public let depth: Int
    
    // MARK: - 样式配置
    
    public let barColor: UIColor
    public let barWidth: CGFloat
    public let barLeftMargin: CGFloat
    
    // MARK: - Init
    
    public init(
        attributedString: NSAttributedString,
        depth: Int,
        barColor: UIColor,
        barWidth: CGFloat,
        barLeftMargin: CGFloat
    ) {
        self.attributedString = attributedString
        self.depth = depth
        self.barColor = barColor
        self.barWidth = barWidth
        self.barLeftMargin = barLeftMargin
    }
}
