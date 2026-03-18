import UIKit
import XHSMarkdownKit
import SnapKit

// MARK: - View Controller

@MainActor
final class StreamingDemoViewController: UIViewController {
    private let autoScrollCoordinator = StreamingDemoAutoScrollCoordinator()
    private var pendingScrollHint: StreamingDemoScrollHint?
    private var isScrollHintFlushScheduled = false

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
        viewModel.selectScenario(at: 0)
    }

    private func setupUI() {
        title = "流式+动画"
        view.backgroundColor = .systemBackground

        let controlsStack = UIStackView(arrangedSubviews: [startButton, stopButton, replayButton, resetButton])
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
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
        startScenario(at: selectedScenarioIndex)
    }

    func replayCurrentScenario() {
        let index = lastScenarioIndex ?? selectedScenarioIndex
        startScenario(at: index)
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
        if abs(oldValue - height) < 0.5 {
            return
        }

        messages[index].heightCache = height
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
    func startScenario(at index: Int) {
        guard scenarios.indices.contains(index) else { return }

        stopStreaming(emitStatus: false)
        let scenario = scenarios[index]
        lastScenarioIndex = index

        appendUserMessage(for: scenario)
        guard let assistantID = appendAssistantMessage(for: scenario) else {
            output?.viewModel(self, didUpdateStatus: "streaming engine 不可用")
            return
        }

        activeAssistantMessageID = assistantID
        let runToken = UUID()
        activeRunToken = runToken

        output?.viewModel(self, didUpdateStatus: "准备中 · \(scenario.title)")
        output?.viewModel(self, didEmitScrollHint: .followBottomIfPossible(animated: true))

        let configuration = MarkdownNetworkStreamSimulator.Configuration(
            markdown: scenario.assistantMarkdown,
            chunkProfile: scenario.chunkProfile,
            networkProfile: scenario.networkProfile
        )

        streamService.start(configuration: configuration) { [weak self] event in
            self?.handle(event: event, for: assistantID, runToken: runToken)
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
        view.animationEffectKey = .typing
        view.animationMode = .dualPhase
        view.typingCharactersPerSecond = 38
        view.animationConcurrencyPolicy = .fullyOrdered
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
        delegate = nil
        messageID = nil
        boundRuntime?.detach()
        boundRuntime = nil
        currentMarkdownHeight = 1
        markdownHeightConstraint?.update(offset: 1)
        markdownView.skipAnimation()
    }

    func configure(
        message: StreamingDemoMessage,
        runtime: MarkdownRuntime?,
        delegate: StreamingDemoMessageCellDelegate
    ) {
        self.delegate = delegate
        self.messageID = message.id

        applyRoleStyle(message.role)

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
}

extension StreamingDemoMessageCell: MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        let resolved = max(1, ceil(height))
        if abs(resolved - currentMarkdownHeight) < 0.5 {
            return
        }

        currentMarkdownHeight = resolved
        markdownHeightConstraint?.update(offset: resolved)
        guard let messageID else { return }
        delegate?.streamingDemoMessageCell(self, didChangeContentHeight: resolved, for: messageID)
    }
}
