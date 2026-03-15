import UIKit
import XHSMarkdownKit

final class AnimationDemoViewController: UIViewController {

    private enum EffectMode: Int {
        case instant
        case typing
        case streamingMask
    }

    private enum ContentPreset: Int, CaseIterable {
        case releasePlan
        case listHeavy
        case codeFocus
        case mixedDocument

        var title: String {
            switch self {
            case .releasePlan:
                return "发布计划"
            case .listHeavy:
                return "清单列表"
            case .codeFocus:
                return "代码说明"
            case .mixedDocument:
                return "混合文档"
            }
        }

        var markdown: String {
            switch self {
            case .releasePlan:
                return """
                # 发布计划

                本周需要完成以下目标：

                1. 梳理 Contract 输入输出字段
                2. 完成动画状态机自检
                3. 输出回归测试结果

                > 注意：上线前需验证 `latestWins` 模式下的中断行为。
                """

            case .listHeavy:
                return """
                # 每日执行清单

                - [ ] 早会同步风险
                - [ ] 开发任务
                  - [ ] SceneDiff 稳定性
                  - [ ] RenderCommit 事务一致性
                  - [ ] 动画收敛策略
                - [ ] 代码评审
                  1. 看并发边界
                  2. 看回归风险
                  3. 看可测试性
                - [ ] 晚间总结
                """

            case .codeFocus:
                return """
                # 动画配置示例

                ```swift
                let container = ExampleMarkdownRuntime.makeConfiguredContainer()
                container.animationEffectKey = .typing
                container.animationConcurrencyPolicy = .latestWins
                container.typingCharactersPerSecond = 42
                container.typingEntityAppearanceMode = .sequential
                try? container.setContractMarkdown(markdown)
                ```

                `typingCharactersPerSecond` 越高，动画越快。
                """

            case .mixedDocument:
                return """
                # Sprint 追踪

                ## 进度
                - 核心链路：**80%**
                - 自动化测试：*进行中*
                - 文档补充：~~未开始~~ 已完成

                ## 风险
                > 当前主要风险是「流式中断后状态残留」。

                ## 下一步
                1. 先修复状态机边界
                2. 再做全量回归
                3. 最后补文档和 demo
                """
            }
        }
    }

    private lazy var rootScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var contentSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ContentPreset.allCases.map(\.title))
        control.selectedSegmentIndex = ContentPreset.releasePlan.rawValue
        control.addTarget(self, action: #selector(contentPresetChanged), for: .valueChanged)
        return control
    }()

    private lazy var contentTextView: UITextView = {
        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 10
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private lazy var effectSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Instant", "Typing", "Mask"])
        control.selectedSegmentIndex = EffectMode.typing.rawValue
        control.addTarget(self, action: #selector(effectChanged), for: .valueChanged)
        return control
    }()

    private lazy var concurrencySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Queue", "Latest"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(configurationChanged), for: .valueChanged)
        return control
    }()

    private lazy var entityAppearanceSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Sequential", "Simultaneous"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(configurationChanged), for: .valueChanged)
        return control
    }()

    private lazy var typingSpeedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 5
        slider.maximumValue = 120
        slider.value = 36
        slider.addTarget(self, action: #selector(typingSpeedChanged), for: .valueChanged)
        return slider
    }()

    private lazy var typingSpeedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var streamSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.isOn = true
        uiSwitch.addTarget(self, action: #selector(streamModeChanged), for: .valueChanged)
        return uiSwitch
    }()

    private lazy var streamChunkSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 16
        slider.value = 5
        slider.addTarget(self, action: #selector(streamChunkChanged), for: .valueChanged)
        return slider
    }()

    private lazy var streamChunkLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var streamIntervalSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 20
        slider.maximumValue = 280
        slider.value = 70
        slider.addTarget(self, action: #selector(streamIntervalChanged), for: .valueChanged)
        return slider
    }()

    private lazy var streamIntervalLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("播放", for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        button.addTarget(self, action: #selector(playAnimation), for: .touchUpInside)
        return button
    }()

    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("跳过动画", for: .normal)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.tintColor = .systemBlue
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        button.addTarget(self, action: #selector(skipAnimation), for: .touchUpInside)
        return button
    }()

    private lazy var previewScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .secondarySystemBackground
        scrollView.layer.cornerRadius = 12
        scrollView.layer.borderWidth = 1
        scrollView.layer.borderColor = UIColor.systemGray4.cgColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var containerView: MarkdownContainerView = {
        let container = ExampleMarkdownRuntime.makeConfiguredContainer()
        container.delegate = self
        return container
    }()

    private lazy var runtime: MarkdownRuntime = {
        let runtime = ExampleMarkdownRuntime.makeRuntime()
        runtime.eventHandler = { event in
            if event.action == "activate",
               case let .string(url)? = event.payload["url"],
               (url.hasPrefix("xhs-think://") || url.hasPrefix("xhs-cite://")) {
                return .handled
            }
            return .continueDefault
        }
        return runtime
    }()

    private var streamingTimer: Timer?
    private var streamingSession: MarkdownContract.StreamingMarkdownSession?
    private var streamTokens: [String] = []
    private var streamTokenCursor = 0
    private var streamTotalCharacterCount = 0
    private var streamedCharacterCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "动画 Demo"
        view.backgroundColor = .systemBackground
        setupUI()
        runtime.attach(to: containerView)
        updateControlLabels()
        effectChanged()
        streamModeChanged()
        loadPreset(ContentPreset.releasePlan)
        render()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewContainerFrame()
    }

    deinit {
        stopStreaming()
    }

    private func setupUI() {
        view.addSubview(rootScrollView)
        rootScrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            rootScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rootScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: rootScrollView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: rootScrollView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: rootScrollView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: rootScrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: rootScrollView.widthAnchor, constant: -24)
        ])

        stackView.addArrangedSubview(makeSection(title: "内容选择", content: contentSegmentedControl))

        let contentEditorSection = makeSection(title: "内容编辑", content: contentTextView)
        contentTextView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        stackView.addArrangedSubview(contentEditorSection)

        let animationOptions = UIStackView(arrangedSubviews: [
            labeledRow("动画效果", control: effectSegmentedControl),
            labeledRow("并发策略", control: concurrencySegmentedControl),
            labeledRow("实体出现", control: entityAppearanceSegmentedControl),
            sliderRow(titleLabel: typingSpeedLabel, slider: typingSpeedSlider),
            switchRow(title: "使用流式输入", uiSwitch: streamSwitch),
            sliderRow(titleLabel: streamChunkLabel, slider: streamChunkSlider),
            sliderRow(titleLabel: streamIntervalLabel, slider: streamIntervalSlider)
        ])
        animationOptions.axis = .vertical
        animationOptions.spacing = 12
        stackView.addArrangedSubview(makeSection(title: "动画配置", content: animationOptions))

        let actionRow = UIStackView(arrangedSubviews: [playButton, skipButton, UIView()])
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 10
        stackView.addArrangedSubview(actionRow)

        stackView.addArrangedSubview(statusLabel)

        stackView.addArrangedSubview(makeSection(title: "预览", content: previewScrollView))
        previewScrollView.heightAnchor.constraint(equalToConstant: 360).isActive = true
        previewScrollView.addSubview(containerView)
    }

    private func makeSection(title: String, content: UIView) -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label

        container.addSubview(titleLabel)
        container.addSubview(content)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            content.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func labeledRow(_ title: String, control: UIView) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabel

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        return row
    }

    private func sliderRow(titleLabel: UILabel, slider: UISlider) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [titleLabel, slider])
        row.axis = .vertical
        row.spacing = 6
        return row
    }

    private func switchRow(title: String, uiSwitch: UISwitch) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabel

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), uiSwitch])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        return row
    }

    private func loadPreset(_ preset: ContentPreset) {
        contentTextView.text = preset.markdown
    }

    private func updateControlLabels() {
        typingSpeedLabel.text = "打字速度: \(resolvedTypingSpeed) 字/秒"
        streamChunkLabel.text = "流式分片: \(resolvedStreamChunkSize) 字/次"
        streamIntervalLabel.text = "流式间隔: \(resolvedStreamIntervalMS) ms"
    }

    private var resolvedEffectMode: EffectMode {
        EffectMode(rawValue: effectSegmentedControl.selectedSegmentIndex) ?? .typing
    }

    private var resolvedTypingSpeed: Int {
        max(1, Int(typingSpeedSlider.value.rounded()))
    }

    private var resolvedStreamChunkSize: Int {
        max(1, Int(streamChunkSlider.value.rounded()))
    }

    private var resolvedStreamIntervalMS: Int {
        max(20, Int(streamIntervalSlider.value.rounded()))
    }

    private func applyAnimationConfiguration() {
        containerView.typingCharactersPerSecond = resolvedTypingSpeed
        containerView.typingEntityAppearanceMode = entityAppearanceSegmentedControl.selectedSegmentIndex == 0
            ? .sequential
            : .simultaneous
        containerView.animationConcurrencyPolicy = concurrencySegmentedControl.selectedSegmentIndex == 0
            ? .fullyOrdered
            : .latestWins

        switch resolvedEffectMode {
        case .instant:
            containerView.animationEffectKey = .instant
            containerView.animationMode = .instant
        case .typing:
            containerView.animationEffectKey = .typing
            containerView.animationMode = .dualPhase
        case .streamingMask:
            containerView.animationEffectKey = .streamingMask
            containerView.animationMode = .dualPhase
        }
    }

    private func render() {
        stopStreaming()
        applyAnimationConfiguration()
        updatePreviewContainerFrame()

        let markdown = contentTextView.text ?? ""
        if streamSwitch.isOn {
            startStreaming(markdown)
            return
        }

        do {
            try runtime.setInput(
                .markdown(
                    text: markdown,
                    documentID: "animation.demo",
                    rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                )
            )
            statusLabel.text = "模式: 一次性渲染"
        } catch {
            statusLabel.text = "渲染失败: \(error.localizedDescription)"
        }
    }

    private func startStreaming(_ markdown: String) {
        streamTokens = MarkdownStreamingChunker.tokenize(markdown)
        streamTokenCursor = 0
        streamTotalCharacterCount = markdown.count
        streamedCharacterCount = 0

        if let engine = containerView.contractStreamingEngine {
            streamingSession = MarkdownContract.StreamingMarkdownSession(
                engine: engine,
                parseOptions: .init(documentId: "animation.demo.stream")
            )
        } else {
            streamingSession = nil
        }

        statusLabel.text = "模式: 流式输入（进行中）"

        let interval = TimeInterval(Double(resolvedStreamIntervalMS) / 1000.0)
        streamingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.emitNextChunk()
            }
        }
    }

    private func emitNextChunk() {
        guard streamTokenCursor < streamTokens.count else {
            finishStreaming()
            return
        }

        let next = MarkdownStreamingChunker.nextChunk(
            from: streamTokens,
            cursor: streamTokenCursor,
            preferredCharacterCount: resolvedStreamChunkSize
        )
        let chunk = next.chunk
        streamTokenCursor = next.nextCursor
        streamedCharacterCount += chunk.count

        do {
            if let session = streamingSession {
                let update = try session.appendChunk(chunk)
                try runtime.setRenderModel(update.model, isFinal: update.isFinal)
            } else {
                try runtime.setInput(
                    .markdown(
                        text: String(streamTokens.prefix(streamTokenCursor).joined()),
                        documentID: "animation.demo.stream",
                        rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                    )
                )
            }
        } catch {
            // Intermediate chunks can be invalid markdown; keep session alive.
        }

        statusLabel.text = "模式: 流式输入（\(streamedCharacterCount)/\(streamTotalCharacterCount)）"

        if streamTokenCursor >= streamTokens.count {
            finishStreaming()
        }
    }

    private func finishStreaming() {
        do {
            if let session = streamingSession {
                let update = try session.finish()
                try runtime.setRenderModel(update.model, isFinal: true)
            } else {
                try runtime.setInput(
                    .markdown(
                        text: contentTextView.text ?? "",
                        documentID: "animation.demo.stream",
                        rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                    )
                )
            }
            statusLabel.text = "模式: 流式输入（完成）"
        } catch {
            let markdown = contentTextView.text ?? ""
            try? runtime.setInput(
                .markdown(
                    text: markdown,
                    documentID: "animation.demo.stream",
                    rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                )
            )
            statusLabel.text = "流式完成失败，已回退整段渲染"
        }

        stopStreaming()
    }

    private func stopStreaming() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        streamingSession = nil
        streamTokens = []
        streamTokenCursor = 0
        streamTotalCharacterCount = 0
        streamedCharacterCount = 0
    }

    private func updatePreviewContainerFrame() {
        let width = previewScrollView.bounds.width
        guard width > 24 else { return }

        containerView.frame = CGRect(
            x: 12,
            y: 12,
            width: width - 24,
            height: containerView.contentHeight
        )

        previewScrollView.contentSize = CGSize(width: width, height: containerView.contentHeight + 24)
    }

    @objc private func contentPresetChanged() {
        guard let preset = ContentPreset(rawValue: contentSegmentedControl.selectedSegmentIndex) else { return }
        loadPreset(preset)
        render()
    }

    @objc private func effectChanged() {
        let isInstant = resolvedEffectMode == .instant
        entityAppearanceSegmentedControl.isEnabled = !isInstant
        typingSpeedSlider.isEnabled = !isInstant
        streamChunkSlider.isEnabled = streamSwitch.isOn
        streamIntervalSlider.isEnabled = streamSwitch.isOn
        updateControlLabels()
    }

    @objc private func streamModeChanged() {
        let enabled = streamSwitch.isOn
        streamChunkSlider.isEnabled = enabled
        streamIntervalSlider.isEnabled = enabled
        updateControlLabels()
    }

    @objc private func typingSpeedChanged() {
        updateControlLabels()
    }

    @objc private func streamChunkChanged() {
        updateControlLabels()
    }

    @objc private func streamIntervalChanged() {
        updateControlLabels()
    }

    @objc private func configurationChanged() {
        updateControlLabels()
    }

    @objc private func playAnimation() {
        render()
    }

    @objc private func skipAnimation() {
        if streamingTimer != nil {
            stopStreaming()
            do {
                try runtime.setInput(
                    .markdown(
                        text: contentTextView.text ?? "",
                        documentID: "animation.demo.stream",
                        rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                    )
                )
            } catch {
                statusLabel.text = "停止流式后回填失败: \(error.localizedDescription)"
            }
        }
        containerView.skipAnimation()
        statusLabel.text = "已跳过当前动画"
    }
}

extension AnimationDemoViewController: MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        updatePreviewContainerFrame()
    }
}
