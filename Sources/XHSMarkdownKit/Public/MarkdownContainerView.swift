import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

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

    // Kept for source compatibility; scheduling now belongs to runtime internals.
    public var animationSchedulingMode: AnimationSchedulingMode = .groupedByPhase

    public var animationSubmissionMode: AnimationSubmitMode {
        get {
            animationConcurrencyPolicy == .latestWins ? .interruptCurrent : .queueLatest
        }
        set {
            switch newValue {
            case .interruptCurrent:
                animationConcurrencyPolicy = .latestWins
            case .queueLatest:
                animationConcurrencyPolicy = .fullyOrdered
            }
        }
    }

    public var typingCharactersPerSecond: Int = 30 {
        didSet {
            typingCharactersPerSecond = max(1, typingCharactersPerSecond)
        }
    }

    public var typingEntityAppearanceMode: TypingEffect.EntityAppearanceMode = .sequential

    public var sceneDiffer: any SceneDiffering = DefaultSceneDiffer()
    public var sceneDeltaBuilder: any SceneDeltaBuilding = DefaultSceneDeltaBuilder()

    // MARK: - Contract

    public var theme: MarkdownTheme {
        didSet { rerender(isFinal: true) }
    }

    public var contractKit: MarkdownContract.UniversalMarkdownKit
    public var contractStreamingEngine: MarkdownContractEngine?
    public var contractRenderAdapter: MarkdownContract.RenderModelUIKitAdapter

    // MARK: - Delegate

    public weak var delegate: MarkdownContainerViewDelegate?

    // MARK: - Scene Host

    public var currentSceneSnapshot: RenderScene {
        currentScene
    }

    // MARK: - State

    private let contentView = UIView()
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
            self?.contentHeight ?? 0
        },
        animateStructuralChanges: { [weak self] changes in
            self?.viewGraphCoordinator.animateStructuralChanges(changes)
        }
    )

    private var currentScene: RenderScene
    private var lastWidth: CGFloat = 0
    private var transactionVersion: Int = 0
    private var measuredContentHeight: CGFloat = 0
    private var lastNotifiedContentHeight: CGFloat = -1

    private var currentContractModel: MarkdownContract.RenderModel?
    private var contractStreamingSession: MarkdownContract.StreamingMarkdownSession?

    // MARK: - Init

    public init(
        theme: MarkdownTheme = .default,
        contractKit: MarkdownContract.UniversalMarkdownKit = MarkdownContract.UniversalMarkdownKit(),
        contractStreamingEngine: MarkdownContractEngine? = nil,
        contractRenderAdapter: MarkdownContract.RenderModelUIKitAdapter? = nil
    ) {
        self.theme = theme
        self.contractKit = contractKit
        self.contractStreamingEngine = contractStreamingEngine
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
        _ model: MarkdownContract.RenderModel
    ) {
        currentContractModel = model
        contractStreamingSession = nil
        rerender(isFinal: true)
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

    public func resetContractStreamingSession(
        engine: MarkdownContractEngine? = nil,
        differ: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer(),
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
        rerender(isFinal: update.isFinal)
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
        rerender(isFinal: true)
        contractStreamingSession = nil
        return update
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

    // MARK: - Internal

    private func setupStackView() {
        addSubview(contentView)
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

    private func rerender(isFinal: Bool, forceInstant: Bool = false) {
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
            applySceneSnapshot(RenderScene.empty(documentId: contractModel.documentId))
            return
        }

        let diff = sceneDiffer.diff(old: currentScene, new: targetScene)
        guard !diff.isEmpty else {
            applySceneSnapshot(targetScene)
            return
        }

        let delta = sceneDeltaBuilder.makeDelta(old: currentScene, new: targetScene, diff: diff)

        transactionVersion += 1
        let renderFrame = RenderFrame(
            version: transactionVersion,
            previousScene: currentScene,
            targetScene: targetScene,
            diff: diff,
            delta: delta,
            isFinal: isFinal,
            animationMode: resolvedAnimationMode(forceInstant: forceInstant),
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
}
