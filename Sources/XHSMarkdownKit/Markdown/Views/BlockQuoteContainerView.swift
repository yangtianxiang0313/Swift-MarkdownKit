import UIKit

public final class BlockQuoteContainerView: UIView, HeightEstimatable {

    private var childFragments: [RenderFragment] = []
    private var childViews: [UIView] = []
    private var barView: UIView?
    private var config: BlockQuoteContainerConfiguration?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(_ config: BlockQuoteContainerConfiguration) {
        self.childFragments = config.childFragments
        self.config = config

        childViews.forEach { $0.removeFromSuperview() }
        childViews.removeAll()

        for fragment in childFragments {
            guard let factory = fragment as? FragmentViewFactory else { continue }
            let view = factory.makeView()
            factory.configure(view)
            addSubview(view)
            childViews.append(view)
        }

        setupBar()
    }

    private var contentLeftOffset: CGFloat {
        guard let config = config else { return 0 }
        return config.barWidth + config.barLeftMargin
    }

    private func setupBar() {
        guard let config = config else { return }
        barView?.removeFromSuperview()
        let bar = UIView()
        bar.backgroundColor = config.barColor
        addSubview(bar)
        barView = bar
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        let contentWidth = max(1, maxWidth - contentLeftOffset)
        var totalHeight: CGFloat = 0
        for (i, fragment) in childFragments.enumerated() {
            if let estimatable = childViews[safe: i] as? HeightEstimatable {
                let len = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
                totalHeight += estimatable.estimatedHeight(atDisplayedLength: len, maxWidth: contentWidth)
            }
            if i < childFragments.count - 1 {
                totalHeight += fragment.spacingAfter
            }
        }
        return totalHeight
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let config = config else { return }
        
        let offset = contentLeftOffset
        let contentWidth = max(0, bounds.width - offset)

        barView?.frame = CGRect(x: 0, y: 0, width: config.barWidth, height: bounds.height)

        var y: CGFloat = 0
        for (i, fragment) in childFragments.enumerated() {
            guard let view = childViews[safe: i] else { continue }
            let height: CGFloat
            if let estimatable = view as? HeightEstimatable {
                let len = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
                height = estimatable.estimatedHeight(atDisplayedLength: len, maxWidth: contentWidth)
            } else {
                height = view.bounds.height
            }
            view.frame = CGRect(x: offset, y: y, width: contentWidth, height: height)
            y += height
            if i < childFragments.count - 1 {
                y += fragment.spacingAfter
            }
        }
    }
}
