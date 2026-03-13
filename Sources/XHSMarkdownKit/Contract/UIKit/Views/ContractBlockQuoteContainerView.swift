import UIKit

public final class ContractBlockQuoteContainerView: UIView, FragmentContaining, HeightEstimatable, StreamableContent {

    public var differ: FragmentDiffing = DefaultFragmentDiffer()
    public let viewPool = ViewPool()
    public var containerView: UIView { contentView }
    public var managedViews: [String: UIView] = [:]

    private var fragments: [RenderFragment] = []
    private var displayedLength: Int = Int.max
    private var config: ContractBlockQuoteContainerConfiguration?
    private let contentView = UIView()
    private var barViews: [UIView] = []
    private let layoutCoordinator: LayoutCoordinator = DefaultLayoutCoordinator()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        addSubview(contentView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(_ config: ContractBlockQuoteContainerConfiguration) {
        self.config = config
        setupBarsIfNeeded()
        displayedLength = totalContentLength(of: config.childFragments)
        update(config.childFragments)
        setNeedsLayout()
    }

    private var contentLeftOffset: CGFloat {
        guard let config else { return 0 }
        return CGFloat(max(1, config.depth)) * (config.barWidth + config.barLeftMargin)
    }

    private func setupBarsIfNeeded() {
        guard let config else { return }

        if barViews.count != max(1, config.depth) {
            barViews.forEach { $0.removeFromSuperview() }
            barViews.removeAll()

            for _ in 0..<max(1, config.depth) {
                let bar = UIView()
                addSubview(bar)
                barViews.append(bar)
            }
        }

        barViews.forEach { $0.backgroundColor = config.barColor }
    }

    public func update(_ newFragments: [RenderFragment]) {
        let oldFragments = fragments
        let changes = differ.diff(old: oldFragments, new: newFragments)
        fragments = newFragments

        guard !changes.isEmpty else {
            relayoutChildFragments()
            setNeedsLayout()
            return
        }

        let step = AnimationStep(
            id: "contract.blockquote.apply",
            effectKey: .instant,
            changes: changes,
            oldFragments: oldFragments,
            newFragments: newFragments
        )

        layoutCoordinator.apply(step: step, to: self)
        applyRevealToChildren(displayedLength)
        setNeedsLayout()
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        let contentWidth = max(1, maxWidth - contentLeftOffset)
        var totalHeight: CGFloat = 0
        var remaining = max(0, atDisplayedLength)

        for (i, fragment) in fragments.enumerated() {
            guard let view = managedViews[fragment.fragmentId] else { continue }
            let fragmentTotal = fragmentLength(fragment)
            let fragmentDisplayed = min(remaining, fragmentTotal)
            remaining = max(0, remaining - fragmentTotal)

            if let estimatable = view as? HeightEstimatable {
                totalHeight += estimatable.estimatedHeight(
                    atDisplayedLength: fragmentDisplayed,
                    maxWidth: contentWidth
                )
            } else {
                totalHeight += view.bounds.height
            }

            if i < fragments.count - 1 {
                totalHeight += fragment.spacingAfter
            }
        }

        return totalHeight
    }

    public func reveal(upTo length: Int) {
        displayedLength = max(0, min(length, totalContentLength(of: fragments)))
        applyRevealToChildren(displayedLength)
        relayoutChildFragments()
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let config else { return }

        let depth = max(1, config.depth)
        for (index, bar) in barViews.enumerated() {
            let x = CGFloat(index) * (config.barWidth + config.barLeftMargin)
            bar.frame = CGRect(x: x, y: 0, width: config.barWidth, height: bounds.height)
        }

        let offset = CGFloat(depth) * (config.barWidth + config.barLeftMargin)
        contentView.frame = CGRect(
            x: offset,
            y: 0,
            width: max(0, bounds.width - offset),
            height: bounds.height
        )
        let revealMap = childDisplayedLengthMap(totalDisplayedLength: displayedLength)

        layoutCoordinator.relayout(
            fragments: fragments,
            in: self,
            displayedLengthProvider: { fragment in
                revealMap[fragment.fragmentId] ?? self.fragmentLength(fragment)
            }
        )
    }

    private func totalContentLength(of fragments: [RenderFragment]) -> Int {
        fragments.reduce(0) { partial, fragment in
            partial + fragmentLength(fragment)
        }
    }

    private func fragmentLength(_ fragment: RenderFragment) -> Int {
        (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
    }

    private func childDisplayedLengthMap(totalDisplayedLength: Int) -> [String: Int] {
        var map: [String: Int] = [:]
        var remaining = max(0, totalDisplayedLength)
        for fragment in fragments {
            let total = fragmentLength(fragment)
            let displayed = min(remaining, total)
            map[fragment.fragmentId] = displayed
            remaining = max(0, remaining - total)
        }
        return map
    }

    private func applyRevealToChildren(_ length: Int) {
        let revealMap = childDisplayedLengthMap(totalDisplayedLength: length)
        for fragment in fragments {
            guard let view = managedViews[fragment.fragmentId] else { continue }
            guard let streamable = view as? StreamableContent else { continue }
            streamable.reveal(upTo: revealMap[fragment.fragmentId] ?? 0)
        }
    }

    private func relayoutChildFragments() {
        let revealMap = childDisplayedLengthMap(totalDisplayedLength: displayedLength)
        layoutCoordinator.relayout(
            fragments: fragments,
            in: self,
            displayedLengthProvider: { fragment in
                revealMap[fragment.fragmentId] ?? self.fragmentLength(fragment)
            }
        )
    }
}
