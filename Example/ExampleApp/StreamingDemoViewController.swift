import UIKit
import XHSMarkdownKit

@MainActor
final class StreamingDemoViewController: UIViewController {

    private enum Role {
        case user
        case assistant
    }

    private enum ReplyContentPreset: Int, CaseIterable {
        case taskPlan
        case reviewChecklist
        case incidentResponse
        case fullCoverage

        var title: String {
            switch self {
            case .taskPlan:
                return "任务拆解"
            case .reviewChecklist:
                return "评审清单"
            case .incidentResponse:
                return "故障响应"
            case .fullCoverage:
                return "全量覆盖"
            }
        }

        var prompt: String {
            switch self {
            case .taskPlan:
                return "那请把每一项展开成可执行步骤，并标注优先级。"
            case .reviewChecklist:
                return "给我一个本次改造的 Code Review 清单，按风险从高到低排列。"
            case .incidentResponse:
                return "如果上线后动画出现异常，请给我一份应急处理 Runbook。"
            case .fullCoverage:
                return "给我一份完整输出，覆盖自定义节点、特殊格式、表格、代码块和链接交互。"
            }
        }

        var markdown: String {
            switch self {
            case .taskPlan:
                return """
                好的，下面按**可执行步骤 + 优先级**展开：

                ### 1) 开发任务（P0）
                - [ ] 完成 `SceneDelta` 拆分：结构变化 / 内容变化
                - [ ] 接入 `RenderCommitCoordinator`，统一 instant 与 animated 提交
                - [ ] 校验 `latestWins` 与 `fullyOrdered` 两种并发策略

                ### 2) 评审任务（P1）
                - [ ] PR-A：重点看动画状态机是否有中间态泄漏
                - [ ] PR-B：重点看高度同步是否和进度同帧
                - [ ] 输出 review note：风险、建议、回归点

                ### 3) 沟通任务（P1）
                - [ ] 午前同步：说明当前改造范围和影响面
                - [ ] 午后同步：反馈测试结果与剩余风险
                - [ ] 收尾同步：确认上线策略与回滚点

                > 建议节奏：先 P0，再并行推进两个 P1。
                """

            case .reviewChecklist:
                return """
                可以，下面是按风险排序的 review 清单：

                ### P0 - 立即确认
                - [ ] 并发策略切换后，是否存在动画中间态残留
                - [ ] 流式 `appendChunk` 失败时，是否仍能在 `finish` 后收敛为完整内容
                - [ ] `skipAnimation` 是否会留下高度不同步

                ### P1 - 重点确认
                - [ ] 高度变化和动画进度是否同帧提交
                - [ ] 大文档下 `latestWins` 是否造成视觉跳变
                - [ ] 气泡复用时 container 约束是否稳定

                ### P2 - 稳定性确认
                - [ ] 长列表滚动场景是否有抖动
                - [ ] 切后台再回来，流式状态是否恢复正确
                - [ ] 多次快速点击生成，状态机是否仍然收敛
                """

            case .incidentResponse:
                return """
                收到，下面是动画异常的应急 Runbook：

                ### 1) 快速止损（5 分钟内）
                - [ ] 切换到 `instant` 动画模式
                - [ ] 将并发策略强制改为 `fullyOrdered`
                - [ ] 暂停新的流式任务入口

                ### 2) 现场诊断（30 分钟内）
                - [ ] 拉取最近一次异常日志（含 chunk 序列）
                - [ ] 比对 `append` 与 `finish` 的状态转换
                - [ ] 检查是否出现高度回调风暴

                ### 3) 修复与回归
                - [ ] 修复后先灰度 10%
                - [ ] 回归 3 组场景：普通消息 / 长文档 / 快速中断
                - [ ] 全量前确认回滚开关可用

                > 原则：先恢复可用性，再追求动画完整性。
                """
            case .fullCoverage:
                return """
                已切换到全量覆盖输出，下面是统一验收样例：

                @Hero(title: "Streaming Full Coverage", subtitle: "custom nodes + special formats")

                @Panel(style: "warning") {
                - mention: <mention userId="stream-user-01" />
                - badge: <badge text="HOT" />
                - chip: <chip text="A/B 2026Q1" />
                - cite: <Cite id="stream-cite-001">citation-001</Cite>
                }

                <Think id="stream-think-001">
                ### Thinking Plan
                - step 1: parse custom tags
                - step 2: validate tree roles
                - step 3: project runtime state
                </Think>

                行内能力：~~strikethrough~~、`inline code`、[runtime-link](https://example.com/runtime?from=streaming)。

                ```swift
                let runtime = MarkdownRuntime()
                runtime.attach(to: containerView)
                try runtime.setInput(.markdown(text: markdown, documentID: "streaming.full.coverage"))
                ```

                | capability | status | note |
                | --- | :---: | --- |
                | customTag | ✅ | mention/cite/think |
                | specialFormat | ✅ | strike/code/link |
                | streaming | ✅ | chunked append |
                """
            }
        }
    }

    private enum EffectMode: Int {
        case typing
        case streamingMask
        case instant

        var effectKey: AnimationEffectKey {
            switch self {
            case .typing:
                return .typing
            case .streamingMask:
                return .streamingMask
            case .instant:
                return .instant
            }
        }
    }

    private struct ScrollDebugSnapshot: Equatable {
        let reason: String
        let followBottom: Bool
        let streamingActive: Bool
        let offsetY: Int
        let contentHeight: Int
        let boundsHeight: Int
        let insetTop: Int
        let insetBottom: Int
        let minOffsetY: Int
        let maxOffsetY: Int
        let targetY: Int?
        let deltaHeight: Int
        let deltaOffsetY: Int
        let applied: Bool?
    }

    private struct HeightState {
        var reported: CGFloat
    }

    private final class ContainerDelegateProxy: NSObject, MarkdownContainerViewDelegate {
        var onHeightChange: ((CGFloat) -> Void)?

        func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
            onHeightChange?(height)
        }
    }

    @MainActor
    private final class MessageItem {
        let id: String
        let role: Role
        var markdown: String
        var isStreaming: Bool
        var streamSessionStarted: Bool

        let container: MarkdownContainerView
        let delegateProxy: ContainerDelegateProxy
        let runtime: MarkdownRuntime
        var streamingSession: MarkdownContract.StreamingMarkdownSession?

        init(
            id: String = UUID().uuidString,
            role: Role,
            markdown: String,
            isStreaming: Bool = false,
            animationConcurrencyPolicy: AnimationConcurrencyPolicy,
            animationEffectKey: AnimationEffectKey,
            typingCharactersPerSecond: Int,
            contentEntityAppearanceMode: ContentEntityAppearanceMode,
            onHeightChange: ((CGFloat) -> Void)?
        ) {
            self.id = id
            self.role = role
            self.markdown = markdown
            self.isStreaming = isStreaming
            self.streamSessionStarted = false
            self.runtime = ExampleMarkdownRuntime.makeRuntime()
            self.streamingSession = nil

            container = ExampleMarkdownRuntime.makeConfiguredContainer()
            container.animationConcurrencyPolicy = animationConcurrencyPolicy
            container.animationEffectKey = animationEffectKey
            container.animationMode = animationEffectKey == .instant ? .instant : .dualPhase
            container.typingCharactersPerSecond = max(1, typingCharactersPerSecond)
            container.contentEntityAppearanceMode = contentEntityAppearanceMode

            delegateProxy = ContainerDelegateProxy()
            delegateProxy.onHeightChange = onHeightChange
            container.delegate = delegateProxy
            runtime.eventHandler = { event in
                if event.action == "activate",
                   let url = event.payload.valueString(forKey: "url"),
                   (url.hasPrefix("xhs-think://") || url.hasPrefix("xhs-cite://")) {
                    return .handled
                }
                return .continueDefault
            }
            runtime.attach(to: container)
        }

        func renderStatic() {
            do {
                try runtime.setInput(
                    .markdown(
                        text: markdown,
                        documentID: id,
                        rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                    )
                )
            } catch {
                // Keep demo resilient; failed render falls back to plain text paragraph.
                try? runtime.setInput(.markdown(text: markdown, documentID: id))
            }
            isStreaming = false
            streamSessionStarted = false
            streamingSession = nil
        }

        func appendChunk(_ chunk: String) {
            markdown += chunk
            do {
                if !streamSessionStarted {
                    streamSessionStarted = true
                    guard let engine = container.contractStreamingEngine else {
                        try runtime.setInput(
                            .markdown(
                                text: markdown,
                                documentID: id,
                                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                            )
                        )
                        return
                    }
                    streamingSession = MarkdownContract.StreamingMarkdownSession(
                        engine: engine,
                        parseOptions: .init(documentId: id)
                    )
                }

                if let session = streamingSession {
                    let update = try session.appendChunk(chunk)
                    try runtime.setRenderModel(update.model, isFinal: update.isFinal)
                } else {
                    try runtime.setInput(
                        .markdown(
                            text: markdown,
                            documentID: id,
                            rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                        )
                    )
                }
            } catch {
                // Keep the streaming session alive. Intermediate chunks can be temporarily invalid.
            }
        }

        func finishStreaming() {
            if streamSessionStarted {
                do {
                    if let session = streamingSession {
                        let update = try session.finish()
                        try runtime.setRenderModel(update.model, isFinal: update.isFinal)
                    } else {
                        try runtime.setInput(
                            .markdown(
                                text: markdown,
                                documentID: id,
                                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                            )
                        )
                    }
                } catch {
                    // Final fallback to the full accumulated markdown so tail-only rendering cannot persist.
                    do {
                        try runtime.setInput(
                            .markdown(
                                text: markdown,
                                documentID: id,
                                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                            )
                        )
                    } catch {
                        try? runtime.setInput(.markdown(text: markdown, documentID: id))
                    }
                }
            } else {
                renderStatic()
            }
            isStreaming = false
            streamSessionStarted = false
            streamingSession = nil
        }
    }

    private final class BubbleMarkdownCell: UITableViewCell {
        static let reuseID = "BubbleMarkdownCell"

        private let bubbleView = UIView()
        private var leadingConstraint: NSLayoutConstraint!
        private var trailingConstraint: NSLayoutConstraint!
        private var maxWidthConstraint: NSLayoutConstraint!

        private weak var hostedContainer: UIView?
        private var hostedConstraints: [NSLayoutConstraint] = []

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            selectionStyle = .none
            backgroundColor = .clear
            contentView.backgroundColor = .clear

            bubbleView.layer.cornerRadius = 16
            bubbleView.layer.cornerCurve = .continuous
            bubbleView.layer.masksToBounds = true
            bubbleView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(bubbleView)

            leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
            trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
            maxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.82)

            NSLayoutConstraint.activate([
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
                maxWidthConstraint,
                leadingConstraint
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        func configure(with item: MessageItem) {
            switch item.role {
            case .assistant:
                leadingConstraint.isActive = true
                trailingConstraint.isActive = false
                bubbleView.backgroundColor = UIColor.secondarySystemBackground
                bubbleView.layer.borderWidth = 1
                bubbleView.layer.borderColor = UIColor.systemGray4.cgColor

            case .user:
                trailingConstraint.isActive = true
                leadingConstraint.isActive = false
                bubbleView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.14)
                bubbleView.layer.borderWidth = 0
                bubbleView.layer.borderColor = nil
            }

            host(container: item.container)
        }

        private func host(container: UIView) {
            if hostedContainer === container {
                return
            }

            hostedContainer?.removeFromSuperview()
            hostedConstraints.forEach { $0.isActive = false }
            hostedConstraints.removeAll()

            if container.superview != nil {
                container.removeFromSuperview()
            }

            container.translatesAutoresizingMaskIntoConstraints = false
            bubbleView.addSubview(container)
            hostedConstraints = [
                container.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
                container.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
                container.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
                container.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10)
            ]
            NSLayoutConstraint.activate(hostedConstraints)

            hostedContainer = container
        }
    }

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = UIColor.systemGroupedBackground
        table.separatorStyle = .none
        table.keyboardDismissMode = .interactive
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = defaultEstimatedRowHeight
        table.dataSource = self
        table.delegate = self
        table.register(BubbleMarkdownCell.self, forCellReuseIdentifier: BubbleMarkdownCell.reuseID)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private lazy var followLabel: UILabel = {
        let label = UILabel()
        label.text = "跟随底部"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var followSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.isOn = true
        uiSwitch.addTarget(self, action: #selector(followSwitchChanged), for: .valueChanged)
        return uiSwitch
    }()

    private lazy var policyLabel: UILabel = {
        let label = UILabel()
        label.text = "并发"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var policySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Queue", "Latest"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(policyChanged), for: .valueChanged)
        return control
    }()

    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.text = "内容模板"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var contentSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ReplyContentPreset.allCases.map(\.title))
        control.selectedSegmentIndex = ReplyContentPreset.taskPlan.rawValue
        control.addTarget(self, action: #selector(contentPresetChanged), for: .valueChanged)
        return control
    }()

    private lazy var effectLabel: UILabel = {
        let label = UILabel()
        label.text = "动画"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var effectSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Typing", "Mask", "Instant"])
        control.selectedSegmentIndex = EffectMode.typing.rawValue
        control.addTarget(self, action: #selector(effectChanged), for: .valueChanged)
        return control
    }()

    private lazy var entityLabel: UILabel = {
        let label = UILabel()
        label.text = "实体"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var entitySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Seq", "Sim"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(entityModeChanged), for: .valueChanged)
        return control
    }()

    private lazy var speedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var speedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 5
        slider.maximumValue = 120
        slider.value = 32
        slider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        return slider
    }()

    private lazy var streamChunkLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var streamChunkSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 12
        slider.value = 4
        slider.addTarget(self, action: #selector(streamChunkChanged), for: .valueChanged)
        return slider
    }()

    private lazy var streamIntervalLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var streamIntervalSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 20
        slider.maximumValue = 220
        slider.value = 60
        slider.addTarget(self, action: #selector(streamIntervalChanged), for: .valueChanged)
        return slider
    }()

    private lazy var generateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("生成回复", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.addTarget(self, action: #selector(startStreamingReply), for: .touchUpInside)
        return button
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重置", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.addTarget(self, action: #selector(resetConversation), for: .touchUpInside)
        return button
    }()

    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("跳过动画", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.addTarget(self, action: #selector(skipAnimation), for: .touchUpInside)
        return button
    }()

    private lazy var settingsRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [followLabel, followSwitch, UIView(), policyLabel, policySegmentedControl])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }()

    private lazy var contentRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [contentLabel, contentSegmentedControl])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = 6
        return row
    }()

    private lazy var effectRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [effectLabel, effectSegmentedControl, UIView(), entityLabel, entitySegmentedControl])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        return row
    }()

    private lazy var speedRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [speedLabel, speedSlider])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = 6
        return row
    }()

    private lazy var streamChunkRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [streamChunkLabel, streamChunkSlider])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = 6
        return row
    }()

    private lazy var streamIntervalRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [streamIntervalLabel, streamIntervalSlider])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = 6
        return row
    }()

    private lazy var actionsRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [UIView(), skipButton, resetButton, generateButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }()

    private lazy var bottomBar: UIStackView = {
        let controls = UIStackView(arrangedSubviews: [
            settingsRow,
            contentRow,
            effectRow,
            speedRow,
            streamChunkRow,
            streamIntervalRow,
            actionsRow
        ])
        controls.axis = .vertical
        controls.alignment = .fill
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false
        return controls
    }()

    private var messages: [MessageItem] = []
    private var streamingTimer: Timer?
    private var streamTokens: [String] = []
    private var streamTokenCursor = 0
    private var activeStreamingMessageID: String?
    private var shouldFollowBottom = true
    private var isRelayoutScheduled = false
    private var isRelayoutRunning = false
    private var needsAnotherRelayoutPass = false
    private var currentConcurrencyPolicy: AnimationConcurrencyPolicy = .fullyOrdered
    private var heightStateByMessageID: [String: HeightState] = [:]

    private var currentContentPreset: ReplyContentPreset = .taskPlan
    private var currentEffectMode: EffectMode = .typing
    private var currentContentEntityAppearanceMode: ContentEntityAppearanceMode = .sequential
    private var currentTypingCharactersPerSecond: Int = 32
    private var currentStreamChunkSize: Int = 4
    private var currentStreamInterval: TimeInterval = 0.06
    private var lastScrollDebugSnapshot: ScrollDebugSnapshot?
    private var lastScrollDebugTimestamp: TimeInterval = 0
    private var lastUserScrollLoggedOffsetY: CGFloat = .nan
    private var lastKnownTableWidth: CGFloat = 0

    private let defaultEstimatedRowHeight: CGFloat = 110
    private let rowChromeHeight: CGFloat = 28

    private static let scrollDebugEnvKey = "XHS_SCROLL_DEBUG"
    private static let scrollDebugDefaultsKey = "xhs.stream.scroll.debug"

    override func viewDidLoad() {
        super.viewDidLoad()
#if DEBUG
        if UserDefaults.standard.object(forKey: Self.scrollDebugDefaultsKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.scrollDebugDefaultsKey)
        }
#endif
        title = "流式 + 动画"
        view.backgroundColor = UIColor.systemGroupedBackground
        setupUI()
        applyControlStateToUI()
        seedConversation()
    }

    deinit {
        streamingTimer?.invalidate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width
        guard width > 0 else { return }
        if abs(width - lastKnownTableWidth) < 1 {
            return
        }
        lastKnownTableWidth = width
        resetEffectiveHeightsForWidthChange()
    }

    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -10)
        ])
    }

    private func seedConversation() {
        messages = [
            makeMessage(role: .user, markdown: "请给我一个今天待办清单，包含开发、评审和沟通。"),
            makeMessage(
                role: .assistant,
                markdown: """
                当然可以，先给你一个结构化清单：

                - **开发**：完成动画链路重构（Diff -> Commit -> UI）
                - **评审**：review 2 个 PR，重点看并发和回归
                - **沟通**：同步今天风险和阻塞
                """
            )
        ]

        tableView.reloadData()
        scrollToBottom(animated: false)
    }

    private func makeMessage(role: Role, markdown: String, isStreaming: Bool = false) -> MessageItem {
        let messageID = UUID().uuidString
        let item = MessageItem(
            id: messageID,
            role: role,
            markdown: markdown,
            isStreaming: isStreaming,
            animationConcurrencyPolicy: currentConcurrencyPolicy,
            animationEffectKey: currentEffectMode.effectKey,
            typingCharactersPerSecond: currentTypingCharactersPerSecond,
            contentEntityAppearanceMode: currentContentEntityAppearanceMode
        ) { [weak self] newHeight in
            self?.handleReportedHeightChange(messageID: messageID, newHeight: newHeight)
        }

        heightStateByMessageID[messageID] = HeightState(reported: 0)
        if !isStreaming {
            item.renderStatic()
        }
        return item
    }

    private func applyAnimationConfiguration(to container: MarkdownContainerView) {
        container.animationConcurrencyPolicy = currentConcurrencyPolicy
        container.animationEffectKey = currentEffectMode.effectKey
        container.animationMode = currentEffectMode == .instant ? .instant : .dualPhase
        container.typingCharactersPerSecond = currentTypingCharactersPerSecond
        container.contentEntityAppearanceMode = currentContentEntityAppearanceMode
    }

    private func applyAnimationConfigurationToAllMessages() {
        for message in messages {
            applyAnimationConfiguration(to: message.container)
        }
    }

    private func applyControlStateToUI() {
        speedLabel.text = "速度: \(currentTypingCharactersPerSecond) 字/秒"
        streamChunkLabel.text = "分片大小: \(currentStreamChunkSize) 字/次"
        streamIntervalLabel.text = "流式间隔: \(Int(currentStreamInterval * 1000)) ms"

        let isInstant = currentEffectMode == .instant
        entitySegmentedControl.isEnabled = !isInstant
        speedSlider.isEnabled = !isInstant
    }

    private func findMessage(id: String) -> MessageItem? {
        messages.first(where: { $0.id == id })
    }

    @objc private func startStreamingReply() {
        guard streamingTimer == nil else { return }

        let question = makeMessage(role: .user, markdown: currentContentPreset.prompt)
        messages.append(question)

        let streaming = makeMessage(role: .assistant, markdown: "", isStreaming: true)
        messages.append(streaming)
        activeStreamingMessageID = streaming.id

        let startInsert = messages.count - 2
        tableView.performBatchUpdates {
            tableView.insertRows(at: [
                IndexPath(row: startInsert, section: 0),
                IndexPath(row: startInsert + 1, section: 0)
            ], with: .automatic)
        }

        scrollToBottom(animated: true)

        streamTokens = MarkdownStreamingChunker.tokenize(currentContentPreset.markdown)
        streamTokenCursor = 0

        applyAnimationConfiguration(to: streaming.container)
        streaming.container.resetContractStreamingSession()
        scheduleStreamingTimer()
    }

    private func scheduleStreamingTimer() {
        streamingTimer = Timer.scheduledTimer(withTimeInterval: currentStreamInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.emitNextChunk()
            }
        }
    }

    private func restartStreamingTimerIfNeeded() {
        guard activeStreamingMessageID != nil else { return }
        streamingTimer?.invalidate()
        scheduleStreamingTimer()
    }

    private func emitNextChunk() {
        guard let activeStreamingMessageID,
              let message = findMessage(id: activeStreamingMessageID) else {
            stopStreaming()
            return
        }

        guard streamTokenCursor < streamTokens.count else {
            message.finishStreaming()
            stopStreaming()
            return
        }

        let next = MarkdownStreamingChunker.nextChunk(
            from: streamTokens,
            cursor: streamTokenCursor,
            preferredCharacterCount: currentStreamChunkSize
        )
        let chunk = next.chunk
        streamTokenCursor = next.nextCursor

        message.appendChunk(chunk)

        if streamTokenCursor >= streamTokens.count {
            message.finishStreaming()
            stopStreaming()
        }
    }

    private func stopStreaming() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        activeStreamingMessageID = nil
        streamTokens = []
        streamTokenCursor = 0
        requestHeightRelayout(reason: "stream.stop")
    }

    private func handleReportedHeightChange(messageID: String, newHeight: CGFloat) {
        let resolvedHeight = max(0, ceil(newHeight))
        let previous = heightStateByMessageID[messageID] ?? HeightState(reported: 0)
        if abs(previous.reported - resolvedHeight) < 0.5 {
            return
        }

        let next = HeightState(reported: resolvedHeight)
        heightStateByMessageID[messageID] = next

        logScrollState(
            reason: "height.msg",
            note: "mid=\(messageID.prefix(6)) h=\(toDebugInt(previous.reported))->\(toDebugInt(resolvedHeight))"
        )

        requestHeightRelayout(reason: "height.msg")
    }

    private func resetEffectiveHeightsForWidthChange() {
        guard !heightStateByMessageID.isEmpty else { return }
        // Width changes invalidate previous fixed row heights; let rows re-measure.
        for messageID in heightStateByMessageID.keys {
            heightStateByMessageID[messageID] = HeightState(reported: 0)
        }
        requestHeightRelayout(reason: "width.change")
    }

    private func requestHeightRelayout(reason: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.requestHeightRelayout(reason: reason)
            }
            return
        }

        needsAnotherRelayoutPass = true
        guard !isRelayoutScheduled else {
            logScrollState(reason: "relayout.defer")
            return
        }

        isRelayoutScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.drainHeightRelayoutQueue(triggerReason: reason)
        }
    }

    private func drainHeightRelayoutQueue(triggerReason: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.drainHeightRelayoutQueue(triggerReason: triggerReason)
            }
            return
        }

        guard !isRelayoutRunning else {
            needsAnotherRelayoutPass = true
            return
        }

        isRelayoutRunning = true
        defer {
            isRelayoutRunning = false
            isRelayoutScheduled = false
            if needsAnotherRelayoutPass {
                requestHeightRelayout(reason: "relayout.requeue")
            }
        }

        while needsAnotherRelayoutPass {
            needsAnotherRelayoutPass = false
            applyHeightRelayoutPass(triggerReason: triggerReason)
        }
    }

    private func applyHeightRelayoutPass(triggerReason: String) {
        let previousContentHeight = tableView.contentSize.height
        let previousOffsetY = tableView.contentOffset.y
        let minOffsetY = minimumOffsetY()
        var targetY: CGFloat?
        var appliedOffset = false
        var reason = shouldFollowBottom ? "relayout.follow" : "relayout.anchor"

        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()

            if shouldFollowBottom {
                let pinResult = pinBottomWithoutAnimation()
                targetY = pinResult.targetY
                appliedOffset = pinResult.applied
                return
            }

            let delta = tableView.contentSize.height - previousContentHeight
            guard abs(delta) >= 0.5 else { return }

            let maxOffsetY = maximumOffsetY(minOffsetY: minOffsetY)
            let anchoredOffsetY = min(max(previousOffsetY + delta, minOffsetY), maxOffsetY)
            targetY = anchoredOffsetY
            if abs(anchoredOffsetY - tableView.contentOffset.y) >= 0.5 {
                tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: anchoredOffsetY), animated: false)
                appliedOffset = true
            }
        }

        logScrollState(
            reason: reason,
            previousContentHeight: previousContentHeight,
            previousOffsetY: previousOffsetY,
            targetY: targetY,
            applied: appliedOffset,
            note: "src=\(triggerReason)"
        )
    }

    @objc private func resetConversation() {
        stopStreaming()
        heightStateByMessageID.removeAll()
        seedConversation()
    }

    @objc private func skipAnimation() {
        if let activeStreamingMessageID,
           let message = findMessage(id: activeStreamingMessageID) {
            message.finishStreaming()
            stopStreaming()
        }

        for message in messages {
            message.container.skipAnimation()
        }
        requestHeightRelayout(reason: "skip.animation")
    }

    @objc private func followSwitchChanged() {
        shouldFollowBottom = followSwitch.isOn
        logScrollState(reason: "follow.toggle", note: "on=\(shouldFollowBottom ? 1 : 0)")
        if shouldFollowBottom {
            scrollToBottom(animated: true)
        }
    }

    @objc private func policyChanged() {
        currentConcurrencyPolicy = policySegmentedControl.selectedSegmentIndex == 0 ? .fullyOrdered : .latestWins
        applyAnimationConfigurationToAllMessages()
    }

    @objc private func contentPresetChanged() {
        currentContentPreset = ReplyContentPreset(rawValue: contentSegmentedControl.selectedSegmentIndex) ?? .taskPlan
    }

    @objc private func effectChanged() {
        currentEffectMode = EffectMode(rawValue: effectSegmentedControl.selectedSegmentIndex) ?? .typing
        applyControlStateToUI()
        applyAnimationConfigurationToAllMessages()
    }

    @objc private func entityModeChanged() {
        currentContentEntityAppearanceMode = entitySegmentedControl.selectedSegmentIndex == 0 ? .sequential : .simultaneous
        applyAnimationConfigurationToAllMessages()
    }

    @objc private func speedChanged() {
        currentTypingCharactersPerSecond = max(1, Int(speedSlider.value.rounded()))
        applyControlStateToUI()
        applyAnimationConfigurationToAllMessages()
    }

    @objc private func streamChunkChanged() {
        currentStreamChunkSize = max(1, Int(streamChunkSlider.value.rounded()))
        applyControlStateToUI()
    }

    @objc private func streamIntervalChanged() {
        let milliseconds = max(20, Int(streamIntervalSlider.value.rounded()))
        currentStreamInterval = TimeInterval(Double(milliseconds) / 1000.0)
        applyControlStateToUI()
        restartStreamingTimerIfNeeded()
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let bottom = IndexPath(row: messages.count - 1, section: 0)
        logScrollState(
            reason: "scroll.bottom",
            targetY: maximumOffsetY(),
            note: "animated=\(animated ? 1 : 0)"
        )
        tableView.scrollToRow(at: bottom, at: .bottom, animated: animated)
    }

    private func resolvedRowHeight(for messageID: String) -> CGFloat? {
        guard let state = heightStateByMessageID[messageID], state.reported > 0 else {
            return nil
        }
        return ceil(state.reported + rowChromeHeight)
    }

    private func minimumOffsetY() -> CGFloat {
        -tableView.adjustedContentInset.top
    }

    private func maximumOffsetY(minOffsetY: CGFloat? = nil) -> CGFloat {
        let resolvedMin = minOffsetY ?? minimumOffsetY()
        return max(
            resolvedMin,
            tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom
        )
    }

    private func pinBottomWithoutAnimation() -> (targetY: CGFloat, applied: Bool) {
        let targetY = maximumOffsetY()
        if abs(targetY - tableView.contentOffset.y) >= 0.5 {
            tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: targetY), animated: false)
            return (targetY, true)
        }
        return (targetY, false)
    }

    private var isScrollDebugEnabled: Bool {
#if DEBUG
        if let envValue = ProcessInfo.processInfo.environment[Self.scrollDebugEnvKey], envValue == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: Self.scrollDebugDefaultsKey)
#else
        return false
#endif
    }

    private func toDebugInt(_ value: CGFloat) -> Int {
        Int(value.rounded())
    }

    private func logScrollState(
        reason: String,
        previousContentHeight: CGFloat? = nil,
        previousOffsetY: CGFloat? = nil,
        targetY: CGFloat? = nil,
        applied: Bool? = nil,
        note: String? = nil
    ) {
        guard isScrollDebugEnabled else { return }

        let insets = tableView.adjustedContentInset
        let minOffset = minimumOffsetY()
        let maxOffset = maximumOffsetY(minOffsetY: minOffset)
        let offsetY = tableView.contentOffset.y
        let contentHeight = tableView.contentSize.height

        let snapshot = ScrollDebugSnapshot(
            reason: reason,
            followBottom: shouldFollowBottom,
            streamingActive: activeStreamingMessageID != nil,
            offsetY: toDebugInt(offsetY),
            contentHeight: toDebugInt(contentHeight),
            boundsHeight: toDebugInt(tableView.bounds.height),
            insetTop: toDebugInt(insets.top),
            insetBottom: toDebugInt(insets.bottom),
            minOffsetY: toDebugInt(minOffset),
            maxOffsetY: toDebugInt(maxOffset),
            targetY: targetY.map(toDebugInt),
            deltaHeight: previousContentHeight.map { toDebugInt(contentHeight - $0) } ?? 0,
            deltaOffsetY: previousOffsetY.map { toDebugInt(offsetY - $0) } ?? 0,
            applied: applied
        )

        let now = Date.timeIntervalSinceReferenceDate
        if snapshot == lastScrollDebugSnapshot {
            return
        }
        if reason.hasPrefix("scroll."), now - lastScrollDebugTimestamp < 0.08 {
            return
        }

        lastScrollDebugSnapshot = snapshot
        lastScrollDebugTimestamp = now

        var message = "[XHSScroll] r=\(snapshot.reason)"
        message += " follow=\(snapshot.followBottom ? 1 : 0)"
        message += " stream=\(snapshot.streamingActive ? 1 : 0)"
        message += " off=\(snapshot.offsetY)"
        message += " h=\(snapshot.contentHeight)"
        message += " b=\(snapshot.boundsHeight)"
        message += " inset=\(snapshot.insetTop),\(snapshot.insetBottom)"
        message += " range=\(snapshot.minOffsetY)...\(snapshot.maxOffsetY)"
        if snapshot.deltaHeight != 0 {
            message += " dH=\(snapshot.deltaHeight)"
        }
        if snapshot.deltaOffsetY != 0 {
            message += " dY=\(snapshot.deltaOffsetY)"
        }
        if let targetY = snapshot.targetY {
            message += " target=\(targetY)"
        }
        if let applied = snapshot.applied {
            message += " set=\(applied ? 1 : 0)"
        }
        if let note, !note.isEmpty {
            message += " \(note)"
        }
        print(message)
    }
}

private extension StreamingDemoViewController {
}

private extension Dictionary where Key == String, Value == MarkdownContract.Value {
    func valueString(forKey key: String) -> String? {
        guard case let .string(value)? = self[key] else {
            return nil
        }
        return value
    }
}

extension StreamingDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let message = messages[indexPath.row]
        return resolvedRowHeight(for: message.id) ?? defaultEstimatedRowHeight
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let message = messages[indexPath.row]
        return resolvedRowHeight(for: message.id) ?? UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BubbleMarkdownCell.reuseID, for: indexPath) as? BubbleMarkdownCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === tableView else { return }
        let isUserDriven = scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating
        guard isUserDriven else { return }

        let offsetY = scrollView.contentOffset.y
        if lastUserScrollLoggedOffsetY.isFinite, abs(offsetY - lastUserScrollLoggedOffsetY) < 8 {
            return
        }
        lastUserScrollLoggedOffsetY = offsetY
        logScrollState(reason: "scroll.user")
    }
}
