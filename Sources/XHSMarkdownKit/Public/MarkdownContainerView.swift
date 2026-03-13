import UIKit

public final class MarkdownContainerView: UIView, FragmentContaining {

    // MARK: - FragmentContaining

    public var differ: FragmentDiffing = DefaultFragmentDiffer()

    public let viewPool = ViewPool()
    public var containerView: UIView { self }
    public var managedViews: [String: UIView] = [:]

    // MARK: - Animation V3

    public var animationEngine: AnimationEngine = MainThreadAnimationEngine() {
        didSet {
            bindAnimationEngine()
            registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond)
        }
    }
    public var animationPlanProvider: AnimationPlanProvider = DefaultAnimationPlanProvider()
    public var conflictPolicy: ConflictPolicy = .default
    public var animationEffectKey: AnimationEffectKey = .instant
    public var animationSchedulingMode: AnimationSchedulingMode {
        get { conflictPolicy.schedulingMode }
        set { conflictPolicy.schedulingMode = newValue }
    }
    public var animationSubmissionMode: AnimationSubmitMode {
        get { conflictPolicy.submissionMode }
        set { conflictPolicy.submissionMode = newValue }
    }
    public var typingCharactersPerSecond: Int = 30 {
        didSet {
            registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond)
        }
    }
    public var typingFragmentAppearanceMode: TypingEffect.FragmentAppearanceMode = .sequential {
        didSet {
            registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond)
        }
    }

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
    private var transactionVersion: Int = 0

    // MARK: - Init

    public init(
        theme: MarkdownTheme = .default,
        pipeline: MarkdownRenderPipeline = MarkdownRenderPipeline()
    ) {
        self.theme = theme
        self.pipeline = pipeline
        super.init(frame: .zero)
        clipsToBounds = true
        bindAnimationEngine()
        registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond)
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
        currentText = preprocessor.preclosedText
        rerender()
    }

    public func finishStreaming() {
        currentText = preprocessor.currentText
        preprocessor.reset()
        rerender()
        animationEngine.streamDidFinish(in: self)
    }

    /// 强制跳过所有剩余动画，立即展示全部内容
    public func skipAnimation() {
        animationEngine.finishAll(in: self)
    }

    public var contentHeight: CGFloat {
        calculateContentHeight()
    }

    // MARK: - FragmentContaining

    public func update(_ newFragments: [RenderFragment]) {
        let oldFragments = fragments
        let changes = differ.diff(old: oldFragments, new: newFragments)
        fragments = newFragments

        guard !changes.isEmpty else {
            notifyHeightChange()
            return
        }

        transactionVersion += 1
        var policy = conflictPolicy
        policy.defaultEffectKey = animationEffectKey

        let transaction = AnimationTransaction(
            version: transactionVersion,
            sourceFragmentsHint: oldFragments,
            targetFragments: newFragments,
            submissionMode: policy.submissionMode,
            planBuilder: { [differ, animationPlanProvider, policy] source, target in
                let rebuiltChanges = differ.diff(old: source, new: target)
                return animationPlanProvider.makePlan(
                    oldFragments: source,
                    newFragments: target,
                    changes: rebuiltChanges,
                    policy: policy
                )
            }
        )
        animationEngine.submit(transaction, to: self)
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

    private func bindAnimationEngine() {
        animationEngine.onAnimationComplete = { [weak self] in
            guard let self else { return }
            self.delegate?.containerViewDidCompleteAnimation(self)
        }

        animationEngine.onLayoutChange = { [weak self] in
            guard let self else { return }
            self.notifyHeightChange()
        }

        animationEngine.onProgress = { [weak self] progress in
            guard let self else { return }
            self.delegate?.containerView(self, didUpdateAnimationProgress: progress)
            if let anchorY = progress.revealedHeight {
                self.delegate?.containerView(self, didUpdateRevealAnchor: anchorY)
            }
        }
    }

    private func registerConfigurableEffects(charactersPerSecond: Int) {
        let appearanceMode = typingFragmentAppearanceMode
        animationEngine.registerEffect(.typing) {
            TypingEffect(
                charactersPerSecond: charactersPerSecond,
                fragmentAppearanceMode: appearanceMode
            )
        }
        animationEngine.registerEffect(.streamingMask) {
            CompositeEffect(effects: [
                TypingEffect(
                    charactersPerSecond: charactersPerSecond,
                    fragmentAppearanceMode: appearanceMode
                ),
                SegmentFadeInEffect(),
                GradientMaskRevealEffect()
            ])
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

extension MarkdownContainerView: OverlayHostCapable {
    public var overlayHostView: UIView { self }
}

extension MarkdownContainerView: HeightAnimatableCapable {
    public func applyAnimatedHeight(_ height: CGFloat) {
        let targetHeight = max(0, height)
        if translatesAutoresizingMaskIntoConstraints {
            var newFrame = frame
            newFrame.size.height = targetHeight
            frame = newFrame
        } else {
            invalidateIntrinsicContentSize()
        }
    }
}
