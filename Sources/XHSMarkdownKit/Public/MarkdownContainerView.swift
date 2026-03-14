import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public final class MarkdownContainerView: UIView, SceneAnimationHost {

    // MARK: - Animation

    public var animationEngine: AnimationEngine = MainThreadAnimationEngine() {
        didSet {
            bindAnimationEngine()
            registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond)
        }
    }

    public var contractAnimationPlanMapper: any ContractAnimationPlanMapping = DefaultContractAnimationPlanMapper()
    public var contractRenderModelDiffer: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer()
    public var contractAnimationCompiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler()
    public var sceneDiffer: any SceneDiffering = DefaultSceneDiffer()

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
        didSet { registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond) }
    }

    public var typingEntityAppearanceMode: TypingEffect.EntityAppearanceMode = .sequential {
        didSet { registerConfigurableEffects(charactersPerSecond: typingCharactersPerSecond) }
    }

    // MARK: - Contract

    public var theme: MarkdownTheme {
        didSet { rerender() }
    }

    public var contractKit: MarkdownContract.UniversalMarkdownKit
    public var contractStreamingEngine: MarkdownContractEngine?
    public var contractRenderAdapter = MarkdownContract.RenderModelUIKitAdapter()

    // MARK: - Delegate

    public weak var delegate: MarkdownContainerViewDelegate?

    // MARK: - Scene Host

    public var currentSceneSnapshot: RenderScene {
        currentScene
    }

    // MARK: - State

    private let stackView = UIStackView()
    private lazy var sceneApplier = SceneApplier(stackView: stackView)

    private var managedViews: [String: UIView] = [:]
    private var currentScene: RenderScene
    private var lastWidth: CGFloat = 0
    private var transactionVersion: Int = 0

    private var currentContractModel: MarkdownContract.RenderModel?
    private var contractStreamingSession: MarkdownContract.StreamingMarkdownSession?
    private var pendingContractAnimationPlan: MarkdownContract.CompiledAnimationPlan?

    // MARK: - Init

    public init(
        theme: MarkdownTheme = .default,
        contractKit: MarkdownContract.UniversalMarkdownKit = MarkdownContract.UniversalMarkdownKit(),
        contractStreamingEngine: MarkdownContractEngine? = nil
    ) {
        self.theme = theme
        self.contractKit = contractKit
        self.contractStreamingEngine = contractStreamingEngine

        self.currentScene = RenderScene.empty(documentId: "document")

        super.init(frame: .zero)
        clipsToBounds = true

        setupStackView()
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

    public func resetContractStreamingSession(
        engine: MarkdownContractEngine? = nil,
        differ: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer(),
        animationCompiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler(),
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) {
        if let engine {
            contractStreamingEngine = engine
        }
        guard let resolvedEngine = contractStreamingEngine else {
            contractStreamingSession = nil
            return
        }
        contractStreamingSession = MarkdownContract.StreamingMarkdownSession(
            engine: resolvedEngine,
            differ: differ,
            animationCompiler: animationCompiler,
            parseOptions: parseOptions,
            renderOptions: renderOptions
        )
    }

    @discardableResult
    public func appendContractStreamChunk(_ chunk: String) throws -> MarkdownContract.StreamingRenderUpdate {
        if contractStreamingSession == nil {
            guard let contractStreamingEngine else {
                throw MarkdownContract.ModelError(
                    code: .requiredFieldMissing,
                    message: "Streaming engine not configured",
                    path: "MarkdownContainerView.contractStreamingEngine"
                )
            }
            contractStreamingSession = MarkdownContract.StreamingMarkdownSession(engine: contractStreamingEngine)
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

    @discardableResult
    public func finishContractStreaming() throws -> MarkdownContract.StreamingRenderUpdate {
        if contractStreamingSession == nil {
            guard let contractStreamingEngine else {
                throw MarkdownContract.ModelError(
                    code: .requiredFieldMissing,
                    message: "Streaming engine not configured",
                    path: "MarkdownContainerView.contractStreamingEngine"
                )
            }
            contractStreamingSession = MarkdownContract.StreamingMarkdownSession(engine: contractStreamingEngine)
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

    public func skipAnimation() {
        animationEngine.finishAll(in: self)
    }

    public var contentHeight: CGFloat {
        let fitting = stackView.systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(max(0, fitting.height))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let widthChanged = abs(bounds.width - lastWidth) > 1
        if widthChanged {
            lastWidth = bounds.width
            stackView.frame = bounds
            rerender()
        } else {
            stackView.frame = bounds
        }
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    // MARK: - SceneAnimationHost

    public func applySceneSnapshot(_ scene: RenderScene) {
        currentScene = scene
        _ = sceneApplier.apply(
            scene: scene,
            maxWidth: max(bounds.width, 1),
            managedViews: &managedViews
        )
        notifyHeightChange()
    }

    // MARK: - Internal

    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .fill
        stackView.distribution = .fill
        addSubview(stackView)
    }

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
        let appearanceMode = typingEntityAppearanceMode

        animationEngine.registerEffect(.typing) {
            TypingEffect(
                charactersPerSecond: charactersPerSecond,
                entityAppearanceMode: appearanceMode
            )
        }

        animationEngine.registerEffect(.streamingMask) {
            CompositeEffect(effects: [
                TypingEffect(
                    charactersPerSecond: charactersPerSecond,
                    entityAppearanceMode: appearanceMode
                ),
                SegmentFadeInEffect(),
                GradientMaskRevealEffect()
            ])
        }
    }

    private func rerender() {
        guard bounds.width > 0 else { return }

        guard let contractModel = currentContractModel else {
            applySceneSnapshot(RenderScene.empty(documentId: currentScene.documentId))
            return
        }

        let newScene = contractRenderAdapter.render(
            model: contractModel,
            theme: theme,
            maxWidth: bounds.width
        )

        let sceneDiff = sceneDiffer.diff(old: currentScene, new: newScene)
        let contractAnimationPlan = pendingContractAnimationPlan
        pendingContractAnimationPlan = nil

        guard !sceneDiff.isEmpty else {
            applySceneSnapshot(newScene)
            return
        }

        transactionVersion += 1
        var policy = conflictPolicy
        policy.defaultEffectKey = animationEffectKey

        let transaction = AnimationTransaction(
            version: transactionVersion,
            sourceSceneHint: currentScene,
            targetScene: newScene,
            submissionMode: policy.submissionMode,
            planBuilder: { [contractAnimationPlanMapper, policy, contractAnimationPlan] oldScene, targetScene in
                let rebuilt = self.sceneDiffer.diff(old: oldScene, new: targetScene)
                let mapped: AnimationPlan
                if let contractAnimationPlan {
                    mapped = contractAnimationPlanMapper.makePlan(
                        contractPlan: contractAnimationPlan,
                        oldScene: oldScene,
                        newScene: targetScene,
                        diff: rebuilt,
                        defaultEffectKey: policy.defaultEffectKey
                    )
                } else {
                    mapped = AnimationPlan(steps: [AnimationStep(
                        id: "scene.apply",
                        effectKey: policy.defaultEffectKey,
                        entityIDs: targetScene.entityIDs,
                        fromScene: oldScene,
                        toScene: targetScene
                    )])
                }

                return Self.schedule(mapped, mode: policy.schedulingMode)
            }
        )

        animationEngine.submit(transaction, to: self)
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
                    entityIDs: step.entityIDs,
                    fromScene: step.fromScene,
                    toScene: step.toScene
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
                    entityIDs: step.entityIDs,
                    fromScene: step.fromScene,
                    toScene: step.toScene
                )
            }
            return AnimationPlan(steps: steps)
        }
    }
}
