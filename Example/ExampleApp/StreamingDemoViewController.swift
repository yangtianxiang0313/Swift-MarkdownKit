import UIKit
import XHSMarkdownKit
import SnapKit

private enum StreamingDemoHeightLogger {
    private static let envKey = "XHS_STREAM_HEIGHT_DEBUG"
    private static let defaultsKey = "xhs.streaming.height.debug"

    static var isEnabled: Bool {
#if DEBUG
        if let envValue = ProcessInfo.processInfo.environment[envKey], envValue == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
#else
        return false
#endif
    }

    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[XHSStreamHeight] \(message())")
    }
}

// MARK: - View Controller

@MainActor
final class StreamingDemoViewController: UIViewController {
    private let autoScrollCoordinator = StreamingDemoAutoScrollCoordinator()
    private var pendingScrollHint: StreamingDemoScrollHint?
    private var isScrollHintFlushScheduled = false
    private var animationConfig = StreamingDemoAnimationConfig.default

    private lazy var scenarioSelector: UISegmentedControl = {
        let control = UISegmentedControl(items: viewModel.scenarios.map(\.title))
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(scenarioChanged), for: .valueChanged)
        return control
    }()

    private lazy var startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        return button
    }()

    private lazy var stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("停止", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        return button
    }()

    private lazy var fullChunkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("全量chunk", for: .normal)
        button.setTitleColor(.systemGreen, for: .normal)
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(fullChunkTapped), for: .touchUpInside)
        return button
    }()

    private lazy var replayButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重播", for: .normal)
        button.setTitleColor(.systemIndigo, for: .normal)
        button.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)
        return button
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重置", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.backgroundColor = UIColor.secondarySystemBackground
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        return button
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.text = "准备就绪"
        return label
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemBackground
        tableView.keyboardDismissMode = .interactive
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StreamingDemoMessageCell.self, forCellReuseIdentifier: StreamingDemoMessageCell.reuseIdentifier)
        return tableView
    }()

    private lazy var viewModel: StreamingDemoViewModel = {
        let vm = StreamingDemoViewModel(
            scenarios: StreamingDemoMockData.scenarios,
            streamService: StreamingDemoStreamService(),
            runtimeFactory: { ExampleMarkdownRuntime.makeRuntime() }
        )
        vm.output = self
        return vm
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationItems()
        viewModel.selectScenario(at: 0)
    }

    private func setupUI() {
        title = "流式+动画"
        view.backgroundColor = .systemBackground

        let controlsStack = UIStackView(
            arrangedSubviews: [startButton, fullChunkButton, stopButton, replayButton, resetButton]
        )
        controlsStack.axis = .horizontal
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 8

        let topStack = UIStackView(arrangedSubviews: [scenarioSelector, controlsStack, statusLabel])
        topStack.axis = .vertical
        topStack.spacing = 10

        view.addSubview(topStack)
        view.addSubview(tableView)

        topStack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "配置",
            style: .plain,
            target: self,
            action: #selector(configTapped)
        )
    }

    @objc
    private func scenarioChanged() {
        viewModel.selectScenario(at: scenarioSelector.selectedSegmentIndex)
    }

    @objc
    private func startTapped() {
        autoScrollCoordinator.noteStreamingStart(in: tableView)
        viewModel.startSelectedScenario()
    }

    @objc
    private func fullChunkTapped() {
        autoScrollCoordinator.noteStreamingStart(in: tableView)
        viewModel.startSelectedScenarioInSingleChunk()
    }

    @objc
    private func stopTapped() {
        viewModel.stopStreaming()
    }

    @objc
    private func replayTapped() {
        autoScrollCoordinator.noteStreamingStart(in: tableView)
        viewModel.replayCurrentScenario()
    }

    @objc
    private func resetTapped() {
        pendingScrollHint = nil
        autoScrollCoordinator.reset()
        viewModel.resetConversation()
    }

    @objc
    private func configTapped() {
        presentAnimationConfigMenu()
    }

    private func applyScrollHint(_ hint: StreamingDemoScrollHint) {
        switch hint {
        case let .followBottomIfPossible(animated):
            guard autoScrollCoordinator.shouldAutoScrollAfterMutation(in: tableView) else { return }
            scrollToBottom(animated: animated)
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard viewModel.numberOfMessages > 0 else { return }
        let row = max(0, viewModel.numberOfMessages - 1)
        tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .bottom, animated: animated)
    }

    private func enqueueScrollHint(_ hint: StreamingDemoScrollHint) {
        pendingScrollHint = hint
        flushScrollHintOnNextRunLoop()
    }

    private func flushScrollHintOnNextRunLoop() {
        guard !isScrollHintFlushScheduled else { return }
        isScrollHintFlushScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isScrollHintFlushScheduled = false
            self.tableView.layoutIfNeeded()
            guard let hint = self.pendingScrollHint else { return }
            self.pendingScrollHint = nil
            self.applyScrollHint(hint)
        }
    }

    private func presentAnimationConfigMenu() {
        let alert = UIAlertController(
            title: "动画参数",
            message: animationConfig.summaryText,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "动画模式", style: .default) { [weak self] _ in
            self?.presentAnimationModeSheet()
        })
        alert.addAction(UIAlertAction(title: "效果类型", style: .default) { [weak self] _ in
            self?.presentEffectSheet()
        })
        alert.addAction(UIAlertAction(title: "打字速度", style: .default) { [weak self] _ in
            self?.presentTypingSpeedEditor()
        })
        alert.addAction(UIAlertAction(title: "并发策略", style: .default) { [weak self] _ in
            self?.presentConcurrencySheet()
        })
        alert.addAction(UIAlertAction(title: "实体显隐顺序", style: .default) { [weak self] _ in
            self?.presentAppearanceModeSheet()
        })
        alert.addAction(UIAlertAction(title: "恢复默认", style: .destructive) { [weak self] _ in
            guard let self else { return }
            animationConfig = .default
            applyAnimationConfigChange(status: "动画参数已恢复默认")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        presentConfigAlert(alert)
    }

    private func presentAnimationModeSheet() {
        let alert = UIAlertController(title: "动画模式", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Instant", style: .default) { [weak self] _ in
            guard let self else { return }
            animationConfig.mode = .instant
            applyAnimationConfigChange(status: "动画模式: Instant")
        })
        alert.addAction(UIAlertAction(title: "DualPhase", style: .default) { [weak self] _ in
            guard let self else { return }
            animationConfig.mode = .dualPhase
            applyAnimationConfigChange(status: "动画模式: DualPhase")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        presentConfigAlert(alert)
    }

    private func presentEffectSheet() {
        let alert = UIAlertController(title: "效果类型", message: nil, preferredStyle: .actionSheet)
        let options: [(String, AnimationEffectKey)] = [
            ("Typing", .typing),
            ("SegmentFade", .segmentFade),
            ("MaskReveal", .maskReveal),
            ("StreamingMask", .streamingMask),
            ("Instant", .instant)
        ]
        for (title, key) in options {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                animationConfig.effectKey = key
                applyAnimationConfigChange(status: "效果类型: \(title)")
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        presentConfigAlert(alert)
    }

    private func presentTypingSpeedEditor() {
        let alert = UIAlertController(
            title: "打字速度",
            message: "字符/秒（1~300）",
            preferredStyle: .alert
        )
        alert.addTextField { [current = animationConfig.charactersPerSecond] textField in
            textField.keyboardType = .numberPad
            textField.text = "\(current)"
            textField.placeholder = "例如 38"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self else { return }
            let raw = alert.textFields?.first?.text ?? ""
            guard let value = Int(raw) else { return }
            animationConfig.charactersPerSecond = max(1, min(300, value))
            applyAnimationConfigChange(status: "打字速度: \(animationConfig.charactersPerSecond) cps")
        })
        presentConfigAlert(alert)
    }

    private func presentConcurrencySheet() {
        let alert = UIAlertController(title: "并发策略", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "FullyOrdered", style: .default) { [weak self] _ in
            guard let self else { return }
            animationConfig.concurrencyPolicy = .fullyOrdered
            applyAnimationConfigChange(status: "并发策略: FullyOrdered")
        })
        alert.addAction(UIAlertAction(title: "LatestWins", style: .default) { [weak self] _ in
            guard let self else { return }
            animationConfig.concurrencyPolicy = .latestWins
            applyAnimationConfigChange(status: "并发策略: LatestWins")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        presentConfigAlert(alert)
    }

    private func presentAppearanceModeSheet() {
        let alert = UIAlertController(title: "实体显隐顺序", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Sequential", style: .default) { [weak self] _ in
            guard let self else { return }
            animationConfig.appearanceMode = .sequential
            applyAnimationConfigChange(status: "实体显隐顺序: Sequential")
        })
        alert.addAction(UIAlertAction(title: "Simultaneous", style: .default) { [weak self] _ in
            guard let self else { return }
            animationConfig.appearanceMode = .simultaneous
            applyAnimationConfigChange(status: "实体显隐顺序: Simultaneous")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        presentConfigAlert(alert)
    }

    private func applyAnimationConfigChange(status: String) {
        statusLabel.text = status
        for cell in tableView.visibleCells {
            guard let messageCell = cell as? StreamingDemoMessageCell,
                  let indexPath = tableView.indexPath(for: messageCell),
                  let message = viewModel.message(at: indexPath.row) else {
                continue
            }
            messageCell.configure(
                message: message,
                runtime: viewModel.runtime(for: message.id),
                animationConfig: animationConfig,
                delegate: self
            )
        }
    }

    private func presentConfigAlert(_ alert: UIAlertController) {
        if let popover = alert.popoverPresentationController {
            if let item = navigationItem.rightBarButtonItem {
                // Anchor to the nav button directly to avoid off-screen popover positioning.
                popover.barButtonItem = item
            } else if let navigationBar = navigationController?.navigationBar {
                popover.sourceView = navigationBar
                popover.sourceRect = CGRect(
                    x: navigationBar.bounds.maxX - 24,
                    y: navigationBar.bounds.midY,
                    width: 1,
                    height: 1
                )
            } else {
                popover.sourceView = view
                popover.sourceRect = CGRect(
                    x: view.bounds.maxX - 24,
                    y: view.safeAreaInsets.top + 16,
                    width: 1,
                    height: 1
                )
            }
            popover.permittedArrowDirections = [.up, .down]
        }
        present(alert, animated: true)
    }
}

extension StreamingDemoViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfMessages
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: StreamingDemoMessageCell.reuseIdentifier,
            for: indexPath
        ) as? StreamingDemoMessageCell,
        let message = viewModel.message(at: indexPath.row) else {
            return UITableViewCell()
        }

        cell.configure(
            message: message,
            runtime: viewModel.runtime(for: message.id),
            animationConfig: animationConfig,
            delegate: self
        )
        return cell
    }
}

extension StreamingDemoViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        autoScrollCoordinator.handleDidScroll(scrollView)
    }
}

extension StreamingDemoViewController: StreamingDemoMessageCellDelegate {
    func streamingDemoMessageCell(
        _ cell: StreamingDemoMessageCell,
        didChangeContentHeight height: CGFloat,
        for messageID: UUID
    ) {
        viewModel.updateMeasuredHeight(height, for: messageID)
    }
}

extension StreamingDemoViewController: StreamingDemoViewModelOutput {
    func viewModelDidResetMessages(_ viewModel: StreamingDemoViewModel) {
        tableView.reloadData()
    }

    func viewModel(_ viewModel: StreamingDemoViewModel, didInsert indexPaths: [IndexPath]) {
        autoScrollCoordinator.prepareForContentMutation(in: tableView)
        tableView.insertRows(at: indexPaths, with: .fade)
    }

    func viewModel(_ viewModel: StreamingDemoViewModel, didReload indexPaths: [IndexPath]) {
        guard !indexPaths.isEmpty else { return }
        let validIndexPaths = indexPaths.filter { $0.row < tableView.numberOfRows(inSection: $0.section) }
        guard !validIndexPaths.isEmpty else { return }

        var fallbackReloadPaths: [IndexPath] = []
        for indexPath in validIndexPaths {
            guard let message = viewModel.message(at: indexPath.row) else { continue }
            if let visibleCell = tableView.cellForRow(at: indexPath) as? StreamingDemoMessageCell {
                visibleCell.configure(
                    message: message,
                    runtime: viewModel.runtime(for: message.id),
                    animationConfig: animationConfig,
                    delegate: self
                )
            } else {
                fallbackReloadPaths.append(indexPath)
            }
        }

        guard !fallbackReloadPaths.isEmpty else { return }
        autoScrollCoordinator.prepareForContentMutation(in: tableView)
        tableView.reloadRows(at: fallbackReloadPaths, with: .none)
    }

    func viewModel(_ viewModel: StreamingDemoViewModel, didRequestHeightRecomputeAt _: IndexPath) {
        autoScrollCoordinator.prepareForContentMutation(in: tableView)
        StreamingDemoHeightLogger.log("VC didRequestHeightRecomputeAt queue beginUpdates")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                StreamingDemoHeightLogger.log("VC beginUpdates contentSizeBefore=\(self.tableView.contentSize.height)")
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                StreamingDemoHeightLogger.log("VC endUpdates contentSizeAfter=\(self.tableView.contentSize.height)")
            }
        }
    }

    func viewModel(_ viewModel: StreamingDemoViewModel, didEmitScrollHint hint: StreamingDemoScrollHint) {
        enqueueScrollHint(hint)
    }

    func viewModel(_ viewModel: StreamingDemoViewModel, didUpdateStatus text: String) {
        statusLabel.text = text
    }
}

// MARK: - Types

enum StreamingDemoMessageRole {
    case user
    case assistant
}

enum StreamingDemoMessageRenderState {
    case text(String)
    case markdown(documentID: String, streamRef: MarkdownRenderStreamRef?)
}

struct StreamingDemoMessage {
    let id: UUID
    let role: StreamingDemoMessageRole
    var renderState: StreamingDemoMessageRenderState
    var heightCache: CGFloat
}

struct StreamingDemoScenario {
    let id: String
    let title: String
    let userPrompt: String
    let assistantMarkdown: String
    let chunkProfile: MarkdownNetworkStreamSimulator.ChunkProfile
    let networkProfile: MarkdownNetworkStreamSimulator.NetworkProfile
}

enum StreamingDemoStreamEvent {
    case started(ttfbMs: Int)
    case stalled(durationMs: Int)
    case chunk(index: Int, text: String)
    case completed(totalChunks: Int, totalBytes: Int)
    case failed(Error)
    case cancelled
}

enum StreamingDemoScrollHint {
    case followBottomIfPossible(animated: Bool)
}

enum StreamingDemoDeliveryMode {
    case normal
    case singleChunk
}

struct StreamingDemoAnimationConfig {
    var mode: RenderAnimationMode
    var effectKey: AnimationEffectKey
    var charactersPerSecond: Int
    var concurrencyPolicy: AnimationConcurrencyPolicy
    var appearanceMode: ContentEntityAppearanceMode

    static let `default` = StreamingDemoAnimationConfig(
        mode: .dualPhase,
        effectKey: .typing,
        charactersPerSecond: 38,
        concurrencyPolicy: .fullyOrdered,
        appearanceMode: .sequential
    )

    var summaryText: String {
        [
            "Mode: \(mode.displayName)",
            "Effect: \(effectKey.displayName)",
            "Speed: \(charactersPerSecond) cps",
            "Concurrency: \(concurrencyPolicy.displayName)",
            "Appearance: \(appearanceMode.displayName)"
        ].joined(separator: "\n")
    }
}

private extension RenderAnimationMode {
    var displayName: String {
        switch self {
        case .instant: return "Instant"
        case .dualPhase: return "DualPhase"
        }
    }
}

private extension AnimationConcurrencyPolicy {
    var displayName: String {
        switch self {
        case .latestWins: return "LatestWins"
        case .fullyOrdered: return "FullyOrdered"
        }
    }
}

private extension ContentEntityAppearanceMode {
    var displayName: String {
        switch self {
        case .sequential: return "Sequential"
        case .simultaneous: return "Simultaneous"
        }
    }
}

private extension AnimationEffectKey {
    var displayName: String {
        switch rawValue {
        case AnimationEffectKey.instant.rawValue: return "Instant"
        case AnimationEffectKey.typing.rawValue: return "Typing"
        case AnimationEffectKey.segmentFade.rawValue: return "SegmentFade"
        case AnimationEffectKey.maskReveal.rawValue: return "MaskReveal"
        case AnimationEffectKey.streamingMask.rawValue: return "StreamingMask"
        default: return rawValue
        }
    }
}

// MARK: - ViewModel

@MainActor
protocol StreamingDemoViewModelOutput: AnyObject {
    func viewModelDidResetMessages(_ viewModel: StreamingDemoViewModel)
    func viewModel(_ viewModel: StreamingDemoViewModel, didInsert indexPaths: [IndexPath])
    func viewModel(_ viewModel: StreamingDemoViewModel, didReload indexPaths: [IndexPath])
    func viewModel(_ viewModel: StreamingDemoViewModel, didRequestHeightRecomputeAt indexPath: IndexPath)
    func viewModel(_ viewModel: StreamingDemoViewModel, didEmitScrollHint hint: StreamingDemoScrollHint)
    func viewModel(_ viewModel: StreamingDemoViewModel, didUpdateStatus text: String)
}

@MainActor
final class StreamingDemoViewModel {
    weak var output: StreamingDemoViewModelOutput?

    let scenarios: [StreamingDemoScenario]

    var numberOfMessages: Int {
        messages.count
    }

    private let streamService: StreamingDemoStreamService
    private let runtimeFactory: @MainActor () -> MarkdownRuntime

    private var messages: [StreamingDemoMessage] = []
    private var selectedScenarioIndex: Int = 0
    private var activeAssistantMessageID: UUID?
    private var activeRunToken = UUID()
    private var lastScenarioIndex: Int?
    private var lastDeliveryMode: StreamingDemoDeliveryMode = .normal
    private var runtimeByMessageID: [UUID: MarkdownRuntime] = [:]

    init(
        scenarios: [StreamingDemoScenario],
        streamService: StreamingDemoStreamService,
        runtimeFactory: @escaping @MainActor () -> MarkdownRuntime
    ) {
        self.scenarios = scenarios
        self.streamService = streamService
        self.runtimeFactory = runtimeFactory
    }

    func message(at index: Int) -> StreamingDemoMessage? {
        guard messages.indices.contains(index) else { return nil }
        return messages[index]
    }

    func runtime(for messageID: UUID) -> MarkdownRuntime? {
        runtimeByMessageID[messageID]
    }

    func selectScenario(at index: Int) {
        guard scenarios.indices.contains(index) else { return }
        selectedScenarioIndex = index
        output?.viewModel(self, didUpdateStatus: "场景已切换: \(scenarios[index].title)")
    }

    func startSelectedScenario() {
        startScenario(at: selectedScenarioIndex, deliveryMode: .normal)
    }

    func startSelectedScenarioInSingleChunk() {
        startScenario(at: selectedScenarioIndex, deliveryMode: .singleChunk)
    }

    func replayCurrentScenario() {
        let index = lastScenarioIndex ?? selectedScenarioIndex
        startScenario(at: index, deliveryMode: lastDeliveryMode)
    }

    func resetConversation() {
        stopStreaming(emitStatus: false)
        messages.removeAll()
        runtimeByMessageID.values.forEach { $0.resetStreams() }
        runtimeByMessageID.removeAll()
        activeAssistantMessageID = nil
        activeRunToken = UUID()
        output?.viewModelDidResetMessages(self)
        output?.viewModel(self, didUpdateStatus: "已重置")
    }

    func stopStreaming() {
        stopStreaming(emitStatus: true)
    }

    func updateMeasuredHeight(_ height: CGFloat, for messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let oldValue = messages[index].heightCache
        messages[index].heightCache = height
        StreamingDemoHeightLogger.log(
            "ViewModel updateMeasuredHeight message=\(messageID) old=\(oldValue) new=\(height)"
        )
        output?.viewModel(self, didRequestHeightRecomputeAt: IndexPath(row: index, section: 0))
        output?.viewModel(self, didEmitScrollHint: .followBottomIfPossible(animated: false))
    }
}

private extension StreamingDemoViewModel {
    func stopStreaming(emitStatus: Bool) {
        streamService.stop()
        guard let activeID = activeAssistantMessageID else {
            if emitStatus {
                output?.viewModel(self, didUpdateStatus: "流式已停止")
            }
            return
        }

        if let index = messages.firstIndex(where: { $0.id == activeID }),
           case let .markdown(documentID, streamRef) = messages[index].renderState {
            if let runtime = runtimeByMessageID[activeID], let streamRef {
                runtime.cancelStream(ref: streamRef)
            }
            messages[index].renderState = .markdown(documentID: documentID, streamRef: nil)
        }
        activeAssistantMessageID = nil
        activeRunToken = UUID()
        if emitStatus {
            output?.viewModel(self, didUpdateStatus: "流式已停止")
        }
    }

}

private extension StreamingDemoViewModel {
    func startScenario(at index: Int, deliveryMode: StreamingDemoDeliveryMode) {
        guard scenarios.indices.contains(index) else { return }

        stopStreaming(emitStatus: false)
        let scenario = scenarios[index]
        lastScenarioIndex = index
        lastDeliveryMode = deliveryMode

        appendUserMessage(for: scenario)
        guard let assistantID = appendAssistantMessage(for: scenario) else {
            output?.viewModel(self, didUpdateStatus: "streaming engine 不可用")
            return
        }

        activeAssistantMessageID = assistantID
        let runToken = UUID()
        activeRunToken = runToken

        let modeText = deliveryMode == .singleChunk ? "全量chunk" : "增量chunk"
        output?.viewModel(self, didUpdateStatus: "准备中 · \(scenario.title) · \(modeText)")
        output?.viewModel(self, didEmitScrollHint: .followBottomIfPossible(animated: true))

        let configuration = makeStreamConfiguration(for: scenario, deliveryMode: deliveryMode)

        streamService.start(configuration: configuration) { [weak self] event in
            self?.handle(event: event, for: assistantID, runToken: runToken)
        }
    }

    func makeStreamConfiguration(
        for scenario: StreamingDemoScenario,
        deliveryMode: StreamingDemoDeliveryMode
    ) -> MarkdownNetworkStreamSimulator.Configuration {
        switch deliveryMode {
        case .normal:
            return MarkdownNetworkStreamSimulator.Configuration(
                markdown: scenario.assistantMarkdown,
                chunkProfile: scenario.chunkProfile,
                networkProfile: scenario.networkProfile
            )

        case .singleChunk:
            let fullChunkCharacters = max(1, scenario.assistantMarkdown.count)
            let frameBytes = max(8, scenario.assistantMarkdown.utf8.count + 4)
            return MarkdownNetworkStreamSimulator.Configuration(
                markdown: scenario.assistantMarkdown,
                chunkProfile: .init(
                    preferredCharacters: fullChunkCharacters,
                    jitterCharacters: 0...0
                ),
                networkProfile: .init(
                    ttfbMs: 40...120,
                    receiveBytes: frameBytes...frameBytes,
                    interPacketMs: 0...0,
                    stallProbability: 0,
                    stallMs: 0...0,
                    burstProbability: 0,
                    burstReceiveBytes: frameBytes...frameBytes,
                    burstInterPacketMs: 0...0
                )
            )
        }
    }

    @discardableResult
    func appendUserMessage(for scenario: StreamingDemoScenario) -> UUID {
        let id = UUID()
        let message = StreamingDemoMessage(
            id: id,
            role: .user,
            renderState: .text(scenario.userPrompt),
            heightCache: 0
        )
        let row = messages.count
        messages.append(message)
        output?.viewModel(self, didInsert: [IndexPath(row: row, section: 0)])
        return id
    }

    @discardableResult
    func appendAssistantMessage(for scenario: StreamingDemoScenario) -> UUID? {
        let id = UUID()
        let documentID = "example.streaming.\(id.uuidString)"
        let runtime = runtimeFactory()

        do {
            let streamRef = try runtime.startStream(documentID: documentID)
            runtimeByMessageID[id] = runtime
            let message = StreamingDemoMessage(
                id: id,
                role: .assistant,
                renderState: .markdown(documentID: documentID, streamRef: streamRef),
                heightCache: 1
            )
            let row = messages.count
            messages.append(message)
            output?.viewModel(self, didInsert: [IndexPath(row: row, section: 0)])
            return id
        } catch {
            let fallback = StreamingDemoMessage(
                id: id,
                role: .assistant,
                renderState: .text("初始化流式管线失败: \(error.localizedDescription)"),
                heightCache: 0
            )
            let row = messages.count
            messages.append(fallback)
            output?.viewModel(self, didInsert: [IndexPath(row: row, section: 0)])
            return nil
        }
    }

    func handle(event: StreamingDemoStreamEvent, for messageID: UUID, runToken: UUID) {
        guard runToken == activeRunToken else { return }
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        guard let runtime = runtimeByMessageID[messageID] else {
            output?.viewModel(self, didUpdateStatus: "runtime 不存在")
            return
        }

        switch event {
        case let .started(ttfbMs):
            output?.viewModel(self, didUpdateStatus: "TTFB \(ttfbMs)ms")

        case let .stalled(durationMs):
            output?.viewModel(self, didUpdateStatus: "网络抖动 \(durationMs)ms")

        case let .chunk(index: chunkIndex, text: text):
            do {
                guard case let .markdown(_, streamRef?) = messages[index].renderState else {
                    output?.viewModel(self, didUpdateStatus: "流式上下文缺失")
                    return
                }
                try runtime.appendStreamChunk(ref: streamRef, chunk: text)
                let sequence = runtime.streamRecord(ref: streamRef)?.sequence ?? 0
                output?.viewModel(self, didUpdateStatus: "chunk #\(chunkIndex) · seq \(sequence)")
                output?.viewModel(self, didEmitScrollHint: .followBottomIfPossible(animated: true))
            } catch {
                output?.viewModel(self, didUpdateStatus: "chunk 处理失败: \(error.localizedDescription)")
            }

        case let .completed(totalChunks, totalBytes):
            do {
                guard case let .markdown(documentID, streamRef?) = messages[index].renderState else {
                    output?.viewModel(self, didUpdateStatus: "收尾上下文缺失")
                    return
                }
                try runtime.finishStream(ref: streamRef)
                runtime.cancelStream(ref: streamRef)
                messages[index].renderState = .markdown(documentID: documentID, streamRef: nil)
                output?.viewModel(
                    self,
                    didUpdateStatus: "完成 · \(totalChunks) chunks / \(totalBytes) bytes"
                )
                output?.viewModel(self, didEmitScrollHint: .followBottomIfPossible(animated: true))
            } catch {
                output?.viewModel(self, didUpdateStatus: "收尾失败: \(error.localizedDescription)")
            }
            activeAssistantMessageID = nil

        case let .failed(error):
            if case let .markdown(documentID, streamRef?) = messages[index].renderState {
                runtime.cancelStream(ref: streamRef)
                messages[index].renderState = .markdown(documentID: documentID, streamRef: nil)
            }
            output?.viewModel(self, didUpdateStatus: "流式失败: \(error.localizedDescription)")
            activeAssistantMessageID = nil

        case .cancelled:
            if case let .markdown(documentID, streamRef?) = messages[index].renderState {
                runtime.cancelStream(ref: streamRef)
                messages[index].renderState = .markdown(documentID: documentID, streamRef: nil)
            }
            output?.viewModel(self, didUpdateStatus: "流式已取消")
            activeAssistantMessageID = nil
        }
    }
}

// MARK: - Stream Service

@MainActor
final class StreamingDemoStreamService {
    private var task: Task<Void, Never>?

    func start(
        configuration: MarkdownNetworkStreamSimulator.Configuration,
        onEvent: @escaping (StreamingDemoStreamEvent) -> Void
    ) {
        stop()

        task = Task { [configuration] in
            await MarkdownNetworkStreamSimulator.run(configuration: configuration) { event in
                if Task.isCancelled { return }

                let mappedEvent: StreamingDemoStreamEvent
                switch event {
                case let .started(ttfbMs):
                    mappedEvent = .started(ttfbMs: ttfbMs)
                case let .stalled(durationMs):
                    mappedEvent = .stalled(durationMs: durationMs)
                case let .chunk(index, text):
                    mappedEvent = .chunk(index: index, text: text)
                case let .completed(totalChunks, totalBytes):
                    mappedEvent = .completed(totalChunks: totalChunks, totalBytes: totalBytes)
                }

                await MainActor.run {
                    onEvent(mappedEvent)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Auto Scroll Coordinator

final class StreamingDemoAutoScrollCoordinator {
    private let bottomThreshold: CGFloat = 48

    private var contentExceededViewport = false
    private var followBottom = false
    private var wasNearBottomBeforeMutation = false

    func noteStreamingStart(in tableView: UITableView) {
        updateViewportState(in: tableView)
        let distance = distanceToBottom(in: tableView)
        followBottom = contentExceededViewport && distance <= bottomThreshold
    }

    func reset() {
        contentExceededViewport = false
        followBottom = false
        wasNearBottomBeforeMutation = false
    }

    func prepareForContentMutation(in tableView: UITableView) {
        updateViewportState(in: tableView)
        wasNearBottomBeforeMutation = distanceToBottom(in: tableView) <= bottomThreshold
    }

    func shouldAutoScrollAfterMutation(in tableView: UITableView) -> Bool {
        updateViewportState(in: tableView)

        guard contentExceededViewport else {
            followBottom = false
            return false
        }

        if wasNearBottomBeforeMutation {
            followBottom = true
        }

        return followBottom
    }

    func handleDidScroll(_ scrollView: UIScrollView) {
        guard let tableView = scrollView as? UITableView else { return }
        updateViewportState(in: tableView)

        guard contentExceededViewport else {
            followBottom = false
            return
        }

        let distance = distanceToBottom(in: tableView)
        if distance <= bottomThreshold {
            followBottom = true
            return
        }

        if scrollView.isDragging || scrollView.isTracking || scrollView.isDecelerating {
            followBottom = false
        }
    }
}

private extension StreamingDemoAutoScrollCoordinator {
    func distanceToBottom(in tableView: UITableView) -> CGFloat {
        let visibleMaxY = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
        return max(0, tableView.contentSize.height - visibleMaxY)
    }

    func updateViewportState(in tableView: UITableView) {
        let viewportHeight = tableView.bounds.height - tableView.adjustedContentInset.top - tableView.adjustedContentInset.bottom
        contentExceededViewport = tableView.contentSize.height > max(0, viewportHeight) + 1
    }
}

// MARK: - Message Cell

@MainActor
protocol StreamingDemoMessageCellDelegate: AnyObject {
    func streamingDemoMessageCell(
        _ cell: StreamingDemoMessageCell,
        didChangeContentHeight height: CGFloat,
        for messageID: UUID
    )
}

final class StreamingDemoMessageCell: UITableViewCell {
    static let reuseIdentifier = "StreamingDemoMessageCell"

    private weak var delegate: StreamingDemoMessageCellDelegate?
    private var messageID: UUID?
    private weak var boundRuntime: MarkdownRuntime?

    private lazy var bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var textLabelView: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var markdownView: MarkdownContainerView = {
        let view = ExampleMarkdownRuntime.makeConfiguredContainer()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.delegate = self
        return view
    }()

    private var bubbleLeadingConstraint: Constraint?
    private var bubbleTrailingConstraint: Constraint?
    private var bubbleFixedMarkdownWidthConstraint: Constraint?
    private var markdownHeightConstraint: Constraint?
    private var currentMarkdownHeight: CGFloat = 1

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        let previousMessageID = messageID
        delegate = nil
        messageID = nil
        StreamingDemoHeightLogger.log("Cell prepareForReuse message=\(String(describing: previousMessageID)) resetHeight=1")
        boundRuntime?.detach()
        boundRuntime = nil
        currentMarkdownHeight = 1
        markdownHeightConstraint?.update(offset: 1)
        markdownView.skipAnimation()
    }

    func configure(
        message: StreamingDemoMessage,
        runtime: MarkdownRuntime?,
        animationConfig: StreamingDemoAnimationConfig,
        delegate: StreamingDemoMessageCellDelegate
    ) {
        self.delegate = delegate
        self.messageID = message.id

        applyRoleStyle(message.role)
        applyAnimationConfig(animationConfig)

        switch message.renderState {
        case let .text(text):
            textLabelView.isHidden = false
            markdownView.isHidden = true
            bubbleFixedMarkdownWidthConstraint?.deactivate()
            textLabelView.text = text
            currentMarkdownHeight = 0
            markdownHeightConstraint?.update(offset: 0)
            boundRuntime?.detach()
            boundRuntime = nil

        case .markdown:
            textLabelView.isHidden = true
            markdownView.isHidden = false
            bubbleFixedMarkdownWidthConstraint?.activate()
            currentMarkdownHeight = max(1, message.heightCache)
            StreamingDemoHeightLogger.log(
                "Cell configure markdown message=\(message.id) cache=\(message.heightCache) apply=\(currentMarkdownHeight)"
            )
            markdownHeightConstraint?.update(offset: currentMarkdownHeight)
            guard let runtime else {
                boundRuntime?.detach()
                boundRuntime = nil
                return
            }
            if boundRuntime !== runtime {
                boundRuntime?.detach()
                runtime.attach(to: markdownView)
                boundRuntime = runtime
            }
        }
    }
}

private extension StreamingDemoMessageCell {
    func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(textLabelView)
        bubbleView.addSubview(markdownView)

        bubbleView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
            make.width.lessThanOrEqualTo(contentView.snp.width).multipliedBy(0.84)
            make.leading.greaterThanOrEqualToSuperview().offset(14)
            make.trailing.lessThanOrEqualToSuperview().offset(-14)

            bubbleLeadingConstraint = make.leading.equalToSuperview().offset(14).constraint
            bubbleTrailingConstraint = make.trailing.equalToSuperview().offset(-14).constraint
            // markdown 视图使用固定气泡宽度，避免布局系统把宽度压缩成竖排。
            bubbleFixedMarkdownWidthConstraint = make.width.equalTo(300).priority(.high).constraint
        }

        textLabelView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-10)
        }

        markdownView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-10)
            markdownHeightConstraint = make.height.equalTo(1).constraint
        }

        bubbleLeadingConstraint?.deactivate()
        bubbleTrailingConstraint?.deactivate()
        bubbleFixedMarkdownWidthConstraint?.deactivate()
    }

    func applyRoleStyle(_ role: StreamingDemoMessageRole) {
        bubbleLeadingConstraint?.deactivate()
        bubbleTrailingConstraint?.deactivate()

        switch role {
        case .user:
            bubbleTrailingConstraint?.activate()
            bubbleView.backgroundColor = UIColor.systemBlue
            textLabelView.textColor = .white

        case .assistant:
            bubbleLeadingConstraint?.activate()
            bubbleView.backgroundColor = UIColor.secondarySystemBackground
            textLabelView.textColor = .label
        }
    }

    func applyAnimationConfig(_ config: StreamingDemoAnimationConfig) {
        markdownView.animationEffectKey = config.effectKey
        markdownView.animationMode = config.mode
        markdownView.typingCharactersPerSecond = config.charactersPerSecond
        markdownView.animationConcurrencyPolicy = config.concurrencyPolicy
        markdownView.contentEntityAppearanceMode = config.appearanceMode
    }
}

extension StreamingDemoMessageCell: MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        let resolved = max(1, ceil(height))
        StreamingDemoHeightLogger.log(
            "Cell didChangeContentHeight message=\(String(describing: messageID)) old=\(currentMarkdownHeight) new=\(resolved) intrinsic=\(view.intrinsicContentSize.height) content=\(view.contentHeight)"
        )
        currentMarkdownHeight = resolved
        markdownHeightConstraint?.update(offset: resolved)
        guard let messageID else { return }
        delegate?.streamingDemoMessageCell(self, didChangeContentHeight: resolved, for: messageID)
    }
}
