import UIKit

/// BlockQuoteContainerView 的配置结构体
public struct BlockQuoteContainerConfiguration {
    
    // MARK: - 内容
    
    public let childFragments: [RenderFragment]
    public let depth: Int
    
    // MARK: - 样式配置
    
    public let barColor: UIColor
    public let barWidth: CGFloat
    public let barLeftMargin: CGFloat
    
    // MARK: - Init
    
    public init(
        childFragments: [RenderFragment],
        depth: Int,
        barColor: UIColor,
        barWidth: CGFloat,
        barLeftMargin: CGFloat
    ) {
        self.childFragments = childFragments
        self.depth = depth
        self.barColor = barColor
        self.barWidth = barWidth
        self.barLeftMargin = barLeftMargin
    }
}
