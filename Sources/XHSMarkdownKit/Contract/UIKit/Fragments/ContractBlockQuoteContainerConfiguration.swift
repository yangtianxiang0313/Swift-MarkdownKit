import UIKit

public struct ContractBlockQuoteContainerConfiguration {
    public let childFragments: [RenderFragment]
    public let depth: Int
    public let barColor: UIColor
    public let barWidth: CGFloat
    public let barLeftMargin: CGFloat

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
