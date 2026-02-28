import UIKit

public final class MarkdownContainerView: UIView, FragmentContaining {

    // MARK: - FragmentContaining

    public var differ: FragmentDiffing = DefaultFragmentDiffer()
    public var animationDriver: AnimationDriver = InstantDriver() {
        didSet { bindAnimationDriver() }
    }
    public let viewPool = ViewPool()
    public var containerView: UIView { self }
    public var managedViews: [String: UIView] = [:]

    // MARK: - Pipeline

    public var pipeline: MarkdownRenderPipeline
    public var theme: MarkdownTheme {
        didSet { rerender() }
    }

    // MARK: - Delegate

    public weak var delegate: MarkdownContainerViewDelegate?

    // MARK: - State

    public let stateStore = FragmentStateStore()
    private var currentText: String = ""
    private(set) public var fragments: [RenderFragment] = []
    private var preprocessor = MarkdownPreprocessor()
    private var lastWidth: CGFloat = 0

    // MARK: - Init

    public init(
        theme: MarkdownTheme = .default,
        pipeline: MarkdownRenderPipeline = MarkdownRenderPipeline()
    ) {
        self.theme = theme
        self.pipeline = pipeline
        super.init(frame: .zero)
        clipsToBounds = true
        bindAnimationDriver()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    public func setText(_ text: String) {
        currentText = text
        preprocessor.reset()
        rerender()
    }

    public func appendStreamChunk(_ chunk: String) {
        preprocessor.append(chunk)
        let preclosed = preprocessor.preclosedText
        currentText = preclosed
        rerender()
    }

    public func finishStreaming() {
        currentText = preprocessor.currentText
        preprocessor.reset()
        rerender()
        animationDriver.streamDidFinish()
    }

    /// 强制跳过所有剩余动画，立即展示全部内容
    public func skipAnimation() {
        animationDriver.finishAll()
    }

    public var contentHeight: CGFloat {
        calculateContentHeight()
    }

    // MARK: - FragmentContaining

    public func update(_ newFragments: [RenderFragment]) {
        let oldFragments = fragments
        let changes = differ.diff(old: oldFragments, new: newFragments)
        fragments = newFragments
        animationDriver.apply(changes: changes, fragments: newFragments, to: self)
        notifyHeightChange()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        let widthChanged = abs(bounds.width - lastWidth) > 1
        if widthChanged {
            lastWidth = bounds.width
            rerender()
        }
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    // MARK: - Internal

    private func bindAnimationDriver() {
        animationDriver.onAnimationComplete = { [weak self] in
            guard let self else { return }
            self.delegate?.containerViewDidCompleteAnimation(self)
        }
        animationDriver.onLayoutChange = { [weak self] in
            guard let self else { return }
            self.notifyHeightChange()
        }
    }

    private func rerender() {
        guard bounds.width > 0 else { return }

        let newFragments = pipeline.render(
            currentText,
            maxWidth: bounds.width,
            theme: theme,
            stateStore: stateStore
        )

        update(newFragments)
    }

    private func calculateContentHeight() -> CGFloat {
        var totalHeight: CGFloat = 0
        for (i, fragment) in fragments.enumerated() {
            if let view = managedViews[fragment.fragmentId],
               let estimatable = view as? HeightEstimatable {
                let len = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
                totalHeight += estimatable.estimatedHeight(atDisplayedLength: len, maxWidth: bounds.width)
            }
            if i < fragments.count - 1 {
                totalHeight += fragment.spacingAfter
            }
        }
        return totalHeight
    }

    private func notifyHeightChange() {
        invalidateIntrinsicContentSize()
        delegate?.containerView(self, didChangeContentHeight: contentHeight)
    }
}
