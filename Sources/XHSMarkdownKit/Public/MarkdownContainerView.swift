import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

private final class AnimationStateStoreProxy: AnimationStateBackingStore {
    var base: any AnimationStateBackingStore

    init(base: any AnimationStateBackingStore = MarkdownRenderStore()) {
        self.base = base
    }

    func prepareAnimationState(documentID: String, revealUnitsByEntity: [String: Int]) {
        base.prepareAnimationState(documentID: documentID, revealUnitsByEntity: revealUnitsByEntity)
    }

    func animationState(for key: AnimationEntityKey) -> AnimationEntityProgressState? {
        base.animationState(for: key)
    }

    func animationStates(documentID: String) -> [AnimationEntityKey: AnimationEntityProgressState] {
        base.animationStates(documentID: documentID)
    }

    func setAnimationState(_ state: AnimationEntityProgressState, for key: AnimationEntityKey) {
        base.setAnimationState(state, for: key)
    }

    func removeAnimationStates(documentID: String) {
        base.removeAnimationStates(documentID: documentID)
    }
}

public final class MarkdownContainerView: UIView, SceneAnimationHost {

    // MARK: - Animation

    public var animationMode: RenderAnimationMode = .instant

    public var animationConcurrencyPolicy: AnimationConcurrencyPolicy = .fullyOrdered {
        didSet {
            renderCommitCoordinator.concurrencyPolicy = animationConcurrencyPolicy
        }
    }

    public var animationEffectKey: AnimationEffectKey = .instant {
        didSet {
            animationMode = animationEffectKey == .instant ? .instant : .dualPhase
        }
    }

    public var typingCharactersPerSecond: Int = 30 {
        didSet {
            typingCharactersPerSecond = max(1, typingCharactersPerSecond)
        }
    }

    public var contentEntityAppearanceMode: ContentEntityAppearanceMode = .sequential

    public var sceneDiffer: any SceneDiffering = DefaultSceneDiffer()
    public var sceneDeltaBuilder: any SceneDeltaBuilding = DefaultSceneDeltaBuilder()

    // MARK: - Contract

    public var theme: MarkdownTheme {
        didSet { rerender(isFinal: true) }
    }

    public var contractKit: MarkdownContract.UniversalMarkdownKit
    public var contractRenderAdapter: MarkdownContract.RenderModelUIKitAdapter

    // MARK: - Delegate

    public weak var delegate: MarkdownContainerViewDelegate?
    public private(set) var lastRenderError: Error?

    // MARK: - Scene Host

    public var currentSceneSnapshot: RenderScene {
        currentScene
    }

    // MARK: - State

    private let contentView = UIView()
    private let animationStateStoreProxy = AnimationStateStoreProxy()
    private lazy var viewGraphCoordinator = ViewGraphCoordinator(containerView: contentView)
    var sceneInteractionHandler: ((RenderScene.Node, SceneInteractionPayload) -> Bool)? {
        didSet {
            viewGraphCoordinator.interactionHandler = sceneInteractionHandler
        }
    }

    private lazy var renderCommitCoordinator = RenderCommitCoordinator(
        applyScene: { [weak self] scene in
            self?.applySceneSnapshot(scene)
        },
        viewForEntity: { [weak self] entityID in
            self?.viewGraphCoordinator.view(for: entityID)
        },
        measureHeight: { [weak self] in
            self?.measureAnimatedContentHeight() ?? 0
        },
        animateStructuralChanges: { [weak self] changes in
            self?.viewGraphCoordinator.animateStructuralChanges(changes)
        },
        animationStateStore: animationStateStoreProxy
    )

    private var currentScene: RenderScene
    private var lastWidth: CGFloat = 0
    private var transactionVersion: Int = 0
    private var measuredContentHeight: CGFloat = 0
    private var lastNotifiedContentHeight: CGFloat = -1

    private var currentContractModel: MarkdownContract.RenderModel?
    private let contractModelDiffer: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer()
    private let contractAnimationCompiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler()
    private let contractAnimationPlanMapper: any ContractAnimationPlanMapping = DefaultContractAnimationPlanMapper()

    // MARK: - Init

    public init(
        theme: MarkdownTheme = .default,
        contractKit: MarkdownContract.UniversalMarkdownKit = MarkdownContract.UniversalMarkdownKit(),
        contractRenderAdapter: MarkdownContract.RenderModelUIKitAdapter? = nil
    ) {
        self.theme = theme
        self.contractKit = contractKit
        self.contractRenderAdapter = contractRenderAdapter ?? MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )
        self.currentScene = RenderScene.empty(documentId: "document")

        super.init(frame: .zero)
        clipsToBounds = true

        setupStackView()
        viewGraphCoordinator.interactionHandler = sceneInteractionHandler
        bindRenderCommitCoordinator()
        renderCommitCoordinator.concurrencyPolicy = animationConcurrencyPolicy
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    public func setContractRenderModel(
        _ model: MarkdownContract.RenderModel,
        forceInstant: Bool = false
    ) {
        let oldModel = currentContractModel
        currentContractModel = model
        rerender(
            isFinal: true,
            forceInstant: forceInstant,
            oldContractModel: oldModel,
            compiledAnimationPlan: nil
        )
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
        setContractRenderModel(model)
    }

    public func skipAnimation() {
        renderCommitCoordinator.finishAll()
    }

    public var contentHeight: CGFloat {
        ceil(max(0, measuredContentHeight))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let widthChanged = abs(bounds.width - lastWidth) > 1
        contentView.frame = bounds
        if widthChanged {
            lastWidth = bounds.width
            rerender(isFinal: true, forceInstant: true)
        }
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    // MARK: - SceneAnimationHost

    public func applySceneSnapshot(_ scene: RenderScene) {
        currentScene = scene
        measuredContentHeight = viewGraphCoordinator.apply(scene: scene, maxWidth: max(bounds.width, 1))
        notifyHeightChange()
    }

    // MARK: - Runtime Bridge

    func bindAnimationStateStore(_ store: any AnimationStateBackingStore) {
        animationStateStoreProxy.base = store
    }

    func applyStreamingUpdateFromRuntime(
        _ update: MarkdownContract.StreamingRenderUpdate,
        mode: MarkdownStreamingApplyMode
    ) {
        let oldModel = currentContractModel
        currentContractModel = update.model

        switch mode {
        case .incremental:
            rerender(
                isFinal: update.isFinal,
                oldContractModel: oldModel,
                compiledAnimationPlan: update.compiledAnimationPlan
            )

        case .snapshot:
            rerender(
                isFinal: update.isFinal,
                forceInstant: true,
                oldContractModel: oldModel,
                compiledAnimationPlan: nil
            )
        }
    }

    // MARK: - Internal

    private func setupStackView() {
        addSubview(contentView)
    }

    private func measureAnimatedContentHeight() -> CGFloat {
        guard bounds.width > 0 else { return contentHeight }
        measuredContentHeight = viewGraphCoordinator.relayout(
            scene: currentScene,
            maxWidth: max(bounds.width, 1)
        )
        return contentHeight
    }

    private func bindRenderCommitCoordinator() {
        renderCommitCoordinator.onAnimationComplete = { [weak self] in
            guard let self else { return }
            self.delegate?.containerViewDidCompleteAnimation(self)
        }

        renderCommitCoordinator.onHeightChange = { [weak self] _ in
            guard let self else { return }
            self.notifyHeightChange()
        }

        renderCommitCoordinator.onProgress = { [weak self] progress in
            guard let self else { return }
            self.delegate?.containerView(self, didUpdateAnimationProgress: progress)
        }
    }

    private func rerender(
        isFinal: Bool,
        forceInstant: Bool = false,
        oldContractModel: MarkdownContract.RenderModel? = nil,
        compiledAnimationPlan: MarkdownContract.CompiledAnimationPlan? = nil
    ) {
        guard bounds.width > 0 else { return }

        guard let contractModel = currentContractModel else {
            applySceneSnapshot(RenderScene.empty(documentId: currentScene.documentId))
            return
        }

        let targetScene: RenderScene
        do {
            targetScene = try contractRenderAdapter.render(
                model: contractModel,
                theme: theme,
                maxWidth: bounds.width
            )
        } catch {
            lastRenderError = error
            notifyRenderFailure(error, documentID: contractModel.documentId)
            return
        }
        lastRenderError = nil

        let diff = sceneDiffer.diff(old: currentScene, new: targetScene)
        guard !diff.isEmpty else {
            applySceneSnapshot(targetScene)
            return
        }

        let delta = sceneDeltaBuilder.makeDelta(old: currentScene, new: targetScene, diff: diff)
        let resolvedExecutionPlan = makeExecutionPlan(
            oldContractModel: oldContractModel,
            newContractModel: contractModel,
            delta: delta,
            compiledAnimationPlan: compiledAnimationPlan
        )

        transactionVersion += 1
        let renderFrame = RenderFrame(
            version: transactionVersion,
            previousScene: currentScene,
            targetScene: targetScene,
            diff: diff,
            delta: delta,
            executionPlan: resolvedExecutionPlan,
            isFinal: isFinal,
            animationMode: resolvedAnimationMode(forceInstant: forceInstant),
            defaultEffectKey: animationEffectKey,
            entityAppearanceMode: contentEntityAppearanceMode,
            unitsPerSecond: typingCharactersPerSecond
        )
        renderCommitCoordinator.submit(renderFrame)
    }

    private func resolvedAnimationMode(forceInstant: Bool) -> RenderAnimationMode {
        if forceInstant {
            return .instant
        }
        return animationMode
    }

    private func notifyRenderFailure(_ error: Error, documentID: String) {
        if Thread.isMainThread {
            delegate?.containerView(self, didFailRender: error, forDocumentID: documentID)
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.containerView(self, didFailRender: error, forDocumentID: documentID)
        }
    }

    private func notifyHeightChange() {
        invalidateIntrinsicContentSize()
        let resolvedHeight = contentHeight
        if abs(lastNotifiedContentHeight - resolvedHeight) < 0.5 {
            return
        }
        lastNotifiedContentHeight = resolvedHeight
        SceneDebugLogger.log("Container height document=\(currentScene.documentId) version=\(transactionVersion) height=\(resolvedHeight)")
        delegate?.containerView(self, didChangeContentHeight: contentHeight)
    }

    private func makeExecutionPlan(
        oldContractModel: MarkdownContract.RenderModel?,
        newContractModel: MarkdownContract.RenderModel,
        delta: SceneDelta,
        compiledAnimationPlan: MarkdownContract.CompiledAnimationPlan?
    ) -> RenderExecutionPlan? {
        guard !delta.isEmpty else { return nil }

        if let compiledAnimationPlan {
            return contractAnimationPlanMapper.makePlan(
                contractPlan: compiledAnimationPlan,
                delta: delta,
                defaultEffectKey: animationEffectKey
            )
        }

        guard let oldContractModel else { return nil }
        let modelDiff = contractModelDiffer.diff(old: oldContractModel, new: newContractModel)
        let compiled = contractAnimationCompiler.compile(old: oldContractModel, new: newContractModel, diff: modelDiff)
        return contractAnimationPlanMapper.makePlan(
            contractPlan: compiled,
            delta: delta,
            defaultEffectKey: animationEffectKey
        )
    }
}
