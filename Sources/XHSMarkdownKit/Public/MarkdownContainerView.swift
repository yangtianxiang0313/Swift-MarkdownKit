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
    public var contractAnimationPlanMapper: any ContractAnimationPlanMapping = DefaultContractAnimationPlanMapper()
    public var contractRenderModelDiffer: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer()
    public var contractAnimationCompiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler()
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

    // MARK: - Contract

    public var theme: MarkdownTheme {
        didSet { rerender() }
    }
    public var contractKit = MarkdownContract.UniversalMarkdownKit()
    public var contractRenderAdapter = MarkdownContract.RenderModelUIKitAdapter()

    // MARK: - Delegate

    public weak var delegate: MarkdownContainerViewDelegate?

    // MARK: - State

    private(set) public var fragments: [RenderFragment] = []
    private var lastWidth: CGFloat = 0
    private var transactionVersion: Int = 0
    private var currentContractModel: MarkdownContract.RenderModel?
    private var contractStreamingSession: MarkdownContract.StreamingMarkdownSession?
    private var pendingContractAnimationPlan: MarkdownContract.CompiledAnimationPlan?

    // MARK: - Init

    public init(
        theme: MarkdownTheme = .default
    ) {
        self.theme = theme
        super.init(frame: .zero)
        clipsToBounds = true
        bindAnimationEngine()
        registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    public func setContractRenderModel(
        _ model: MarkdownContract.RenderModel,
        animationPlan: MarkdownContract.CompiledAnimationPlan? = nil
    ) {
        let resolvedPlan: MarkdownContract.CompiledAnimationPlan?
        if let animationPlan {
            resolvedPlan = animationPlan
        } else {
            let oldModel = currentContractModel ?? Self.emptyRenderModel(documentId: model.documentId)
            let diff = contractRenderModelDiffer.diff(old: oldModel, new: model)
            resolvedPlan = diff.isEmpty ? nil : contractAnimationCompiler.compile(old: oldModel, new: model, diff: diff)
        }

        currentContractModel = model
        contractStreamingSession = nil
        pendingContractAnimationPlan = resolvedPlan
        rerender()
    }

    /// Parse markdown through the contract engine and render via `contractRenderAdapter`.
    public func setContractMarkdown(
        _ markdown: String,
        parserID: MarkdownContract.ParserID? = nil,
        rendererID: MarkdownContract.RendererID? = nil,
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        rewritePipeline: MarkdownContract.CanonicalRewritePipeline = MarkdownContract.CanonicalRewritePipeline(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) throws {
        let model = try contractKit.render(
            markdown,
            parserID: parserID,
            rendererID: rendererID,
            parseOptions: parseOptions,
            rewritePipeline: rewritePipeline,
            renderOptions: renderOptions
        )
        setContractRenderModel(model, animationPlan: nil)
    }

    /// Reset a streaming contract session. Use with `appendContractStreamChunk` and `finishContractStreaming`.
    public func resetContractStreamingSession(
        engine: MarkdownContractEngine = MarkdownContractEngine(),
        differ: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer(),
        animationCompiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler(),
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) {
        contractStreamingSession = MarkdownContract.StreamingMarkdownSession(
            engine: engine,
            differ: differ,
            animationCompiler: animationCompiler,
            parseOptions: parseOptions,
            renderOptions: renderOptions
        )
    }

    /// Append streaming markdown in contract mode and return canonical diff/animation DTO update.
    @discardableResult
    public func appendContractStreamChunk(
        _ chunk: String
    ) throws -> MarkdownContract.StreamingRenderUpdate {
        if contractStreamingSession == nil {
            contractStreamingSession = MarkdownContract.StreamingMarkdownSession()
        }

        guard let session = contractStreamingSession else {
            throw MarkdownContract.ModelError(
                code: .requiredFieldMissing,
                message: "Streaming session not initialized",
                path: "contractStreamingSession"
            )
        }

        let update = try session.appendChunk(chunk)
        currentContractModel = update.model
        pendingContractAnimationPlan = update.animationPlan
        rerender()
        return update
    }

    /// Finish contract streaming and emit a final streaming update.
    @discardableResult
    public func finishContractStreaming() throws -> MarkdownContract.StreamingRenderUpdate {
        if contractStreamingSession == nil {
            contractStreamingSession = MarkdownContract.StreamingMarkdownSession()
        }

        guard let session = contractStreamingSession else {
            throw MarkdownContract.ModelError(
                code: .requiredFieldMissing,
                message: "Streaming session not initialized",
                path: "contractStreamingSession"
            )
        }

        let update = try session.finish()
        currentContractModel = update.model
        pendingContractAnimationPlan = update.animationPlan
        rerender()
        animationEngine.streamDidFinish(in: self)
        contractStreamingSession = nil
        return update
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
        update(newFragments, contractAnimationPlan: nil)
    }

    private func update(
        _ newFragments: [RenderFragment],
        contractAnimationPlan: MarkdownContract.CompiledAnimationPlan?
    ) {
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
            planBuilder: { [differ, contractAnimationPlanMapper, policy, contractAnimationPlan] source, target in
                let rebuiltChanges = differ.diff(old: source, new: target)
                if let contractAnimationPlan {
                    let mappedPlan = contractAnimationPlanMapper.makePlan(
                        contractPlan: contractAnimationPlan,
                        oldFragments: source,
                        newFragments: target,
                        changes: rebuiltChanges,
                        defaultEffectKey: policy.defaultEffectKey
                    )
                    return Self.schedule(mappedPlan, mode: policy.schedulingMode)
                }
                return .empty
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

        guard let contractModel = currentContractModel else {
            update([], contractAnimationPlan: nil)
            return
        }

        let newFragments = contractRenderAdapter.render(
            model: contractModel,
            theme: theme,
            maxWidth: bounds.width
        )
        let contractAnimationPlan = pendingContractAnimationPlan
        pendingContractAnimationPlan = nil
        update(newFragments, contractAnimationPlan: contractAnimationPlan)
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

    private static func emptyRenderModel(documentId: String) -> MarkdownContract.RenderModel {
        MarkdownContract.RenderModel(documentId: documentId, blocks: [])
    }

    private static func schedule(_ plan: AnimationPlan, mode: AnimationSchedulingMode) -> AnimationPlan {
        switch mode {
        case .groupedByPhase:
            return plan
        case .serialByChange:
            var previous: AnimationStep.StepID?
            let steps = plan.steps.map { step -> AnimationStep in
                let dependencies = previous.map { Set([$0]) } ?? []
                let rewritten = AnimationStep(
                    id: step.id,
                    dependencies: dependencies,
                    effectKey: step.effectKey,
                    changes: step.changes,
                    oldFragments: step.oldFragments,
                    newFragments: step.newFragments
                )
                previous = step.id
                return rewritten
            }
            return AnimationPlan(steps: steps)
        case .parallelByChange:
            let steps = plan.steps.map { step in
                AnimationStep(
                    id: step.id,
                    dependencies: [],
                    effectKey: step.effectKey,
                    changes: step.changes,
                    oldFragments: step.oldFragments,
                    newFragments: step.newFragments
                )
            }
            return AnimationPlan(steps: steps)
        }
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
