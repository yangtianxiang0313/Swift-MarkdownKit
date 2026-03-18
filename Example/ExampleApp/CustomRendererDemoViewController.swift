import UIKit
import XHSMarkdownKit

class CustomRendererDemoViewController: UIViewController {
    private enum RuntimeMode: String {
        case capability = "runtime_capability"
        case persistence = "persistence_recovery"
    }

    // MARK: - UI

    private lazy var scrollView = UIScrollView()

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 24
        sv.alignment = .fill
        return sv
    }()

    private lazy var demoSelector: UISegmentedControl = {
        let control = UISegmentedControl(items: ["节点流程", "渲染定制", "Runtime", "状态恢复"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(demoChanged), for: .valueChanged)
        return control
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.isHidden = true
        label.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(copyLatestError))
        label.addGestureRecognizer(tap)
        return label
    }()

    private lazy var runtimeSnapshotLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var toggleQuoteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Toggle Quote", for: .normal)
        button.addTarget(self, action: #selector(toggleQuoteState), for: .touchUpInside)
        return button
    }()

    private lazy var triggerCopyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Trigger Copy", for: .normal)
        button.addTarget(self, action: #selector(triggerCopyState), for: .touchUpInside)
        return button
    }()

    private lazy var setCustomStateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Set State", for: .normal)
        button.addTarget(self, action: #selector(setCustomRuntimeState), for: .touchUpInside)
        return button
    }()

    private lazy var clearEventButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear Events", for: .normal)
        button.addTarget(self, action: #selector(clearRuntimeEvents), for: .touchUpInside)
        return button
    }()

    private lazy var loadDocAButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Load Doc A", for: .normal)
        button.addTarget(self, action: #selector(loadPersistenceDocA), for: .touchUpInside)
        return button
    }()

    private lazy var loadDocBButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Load Doc B", for: .normal)
        button.addTarget(self, action: #selector(loadPersistenceDocB), for: .touchUpInside)
        return button
    }()

    private lazy var reloadDocButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reload Doc", for: .normal)
        button.addTarget(self, action: #selector(reloadCurrentRuntimeDoc), for: .touchUpInside)
        return button
    }()

    private lazy var dispatchActivateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dispatch Activate", for: .normal)
        button.addTarget(self, action: #selector(dispatchRuntimeActivate), for: .touchUpInside)
        return button
    }()

    private lazy var runtimeActionRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [toggleQuoteButton, triggerCopyButton, setCustomStateButton, clearEventButton])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fillEqually
        row.spacing = 8
        return row
    }()

    private lazy var runtimePersistenceActionRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [loadDocAButton, loadDocBButton, reloadDocButton, dispatchActivateButton])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fillEqually
        row.spacing = 8
        row.isHidden = true
        return row
    }()

    private lazy var runtimeEventLogView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .label
        tv.backgroundColor = UIColor.systemGray6
        tv.layer.cornerRadius = 8
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.heightAnchor.constraint(equalToConstant: 170).isActive = true
        return tv
    }()

    private lazy var runtimePanel: UIStackView = {
        let panel = UIStackView(arrangedSubviews: [runtimeSnapshotLabel, runtimeActionRow, runtimePersistenceActionRow, runtimeEventLogView])
        panel.axis = .vertical
        panel.alignment = .fill
        panel.spacing = 8
        panel.isHidden = true
        return panel
    }()

    private lazy var containerView: MarkdownContainerView = {
        ExampleMarkdownRuntime.makeConfiguredContainer(theme: .default)
    }()

    @MainActor
    private lazy var runtime: MarkdownRuntime = {
        let runtime = ExampleMarkdownRuntime.makeRuntime()
        runtime.eventHandler = { [weak self] event in
            self?.appendRuntimeEventLog(event)
            self?.refreshRuntimeSnapshotLabel()
            if event.action == "activate", event.nodeKind == ExampleMarkdownRuntime.citeKind {
                self?.appendInfoLog("cite activate 已由外部处理（角标点击事件）。")
                return .handled
            }
            if self?.runtimeMode == .capability, event.action == "activate" {
                self?.appendInfoLog("link activate 已被外部 handler 标记为 handled。")
                return .handled
            }
            return .continueDefault
        }
        return runtime
    }()

    // MARK: - Data

    private let descriptions = [
        "演示新增节点链路：directive/html + block/inline + leaf/container + selfClosing/paired/both。",
        "演示外部自定义：覆盖 block mapper、inline renderer、mark 样式映射。",
        "演示 Runtime 能力：统一事件总线、状态快照、外部事件注入与延迟 effect。",
        "演示状态持久化与关联数据：文档切换恢复、businessContext 透传与主动事件调度。"
    ]

    private let nodeFlowMarkdown = """
    # 新增节点流程矩阵

    @Hero(title: "Node Flow", subtitle: "TagSchema -> NodeSpec -> Parse -> Canonical -> RenderModel")

    @Callout(title: "Block Leaf: Callout")

    @Tabs {
    - iOS
    - Android
    - Web
    }

    @Panel(style: "neutral") {
    ### Panel Container
    这里是 Panel 内容区，包含段落和列表。
    - item A
    - item B
    }

    <Think id="think-node-001">
    ### Thinking
    这是一个可折叠的扩展 block container，内部仍然是 markdown。
    - step 1: parse
    - step 2: canonical
    - step 3: render
    </Think>

    行内节点覆盖：
    <mention userId="new-user" />、
    <spoiler text="剧透内容" />、
    <badge text="NEW" />、
    <chip text="A/B Test" />、
    <Cite id="cite-101">abcdfe</Cite>。

    同时保留核心节点：~~删除线~~、`inline code`、[link](https://example.com)。

    ```swift
    let runtime = MarkdownRuntime()
    try runtime.setInput(.markdown(text: markdown, documentID: "example.custom.nodeFlow"))
    ```

    | 能力 | 覆盖 | 说明 |
    | --- | :---: | --- |
    | 自定义节点 | ✅ | block/inline + leaf/container |
    | 配对模式 | ✅ | selfClosing/paired/both |
    | 特殊格式 | ✅ | strike/code/link/table |
    """

    private let rendererCustomizationMarkdown = """
    # 外部渲染自定义

    下面节点会被外部 mapper / renderer 覆盖：

    @Callout(title: "External Block Mapper")
    @Panel(style: "warning") {
    - mention: <mention userId="renderer-user" />
    - badge: <badge text="CUSTOM" />
    - chip: <chip>Renderer Chip</chip>
    - cite: <Cite id="cite-custom-001">render me</Cite>
    }

    行内格式也保留：~~deprecated~~、`inline-code`、[doc](https://example.com/custom-renderer)。

    ```swift
    let runtime = MarkdownRuntime()
    runtime.attach(to: view)
    ```
    """

    private let runtimeDocumentID = "example.custom.runtime"
    private let runtimePersistenceDocumentA = "example.custom.persistence.docA"
    private let runtimePersistenceDocumentB = "example.custom.persistence.docB"
    private let runtimeQuoteNodeID = "quote-demo"
    private let runtimeCodeNodeID = "code-demo"
    private let runtimeLinkNodeID = "runtime-link-1"
    private var currentRuntimeDocumentID = "example.custom.runtime"
    private var runtimeMode: RuntimeMode = .capability
    private var runtimeEventLogs: [String] = []
    private var latestRenderErrorPayload: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        runtime.attach(to: containerView)
        renderDemo(index: 0)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "自定义渲染器"

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(demoSelector)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(containerView)
        stackView.addArrangedSubview(runtimePanel)

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    // MARK: - Actions

    @objc private func demoChanged() {
        renderDemo(index: demoSelector.selectedSegmentIndex)
    }

    @objc private func copyLatestError() {
        guard let payload = latestRenderErrorPayload, !payload.isEmpty else { return }
        UIPasteboard.general.string = payload
        statusLabel.text = "已复制错误信息到剪贴板。"
    }

    private func renderDemo(index: Int) {
        descriptionLabel.text = descriptions[index]
        runtimePanel.isHidden = index < 2
        runtimePersistenceActionRow.isHidden = index != 3
        switch index {
        case 0:
            renderNodeFlowDemo()
        case 1:
            renderRendererCustomizationDemo()
        case 2:
            renderRuntimeCapabilityDemo()
        case 3:
            renderPersistenceCapabilityDemo()
        default:
            break
        }
    }

    private func renderNodeFlowDemo() {
        containerView.contractRenderAdapter = makeAdapter()
        do {
            try runtime.setInput(
                .markdown(
                    text: nodeFlowMarkdown,
                    documentID: "example.custom.nodeFlow",
                    rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                )
            )
            clearRenderErrorStatus()
        } catch {
            reportRenderError(error, markdown: nodeFlowMarkdown, source: "CustomRendererDemo.nodeFlow")
        }
    }

    private func renderRendererCustomizationDemo() {
        let adapter = makeAdapter()
        adapter.registerBlockMapper(for: .codeBlock) { block, _, adapter in
            let code = block.contractAttrString(for: "code") ?? ""
            let language = block.contractAttrString(for: "language") ?? "text"

            let node = adapter.makeCustomStandaloneNode(
                id: block.id,
                kind: "codeBlock",
                reuseIdentifier: "contract.customCodeBlock",
                signature: "\(language)|\(code)",
                revealUnitCount: max(1, code.count),
                spacingAfter: 16,
                makeView: { CustomCodeBlockView() },
                configure: { view, maxWidth in
                    guard let codeView = view as? CustomCodeBlockView else { return }
                    codeView.configure(code: code, language: language, maxWidth: maxWidth)
                }
            )
            return [.standalone(node)]
        }

        adapter.registerBlockMapper(forExtension: ExampleMarkdownRuntime.calloutKind.rawValue) { block, _, adapter in
            let title = block.contractAttrString(for: "title") ?? "Callout"
            let attributed = NSAttributedString(
                string: "CALLOUT CUSTOM · \(title)",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.systemBlue
                ]
            )
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "callout.custom",
                attributedText: attributed,
                spacingAfter: 12
            )
            return [.mergeSegment(segment)]
        }
        adapter.registerBlockMapper(forExtension: ExampleMarkdownRuntime.panelKind.rawValue) { block, context, adapter in
            let header = NSAttributedString(
                string: "PANEL CUSTOM HEADER",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: UIColor.systemOrange
                ]
            )
            let headerSegment = adapter.makeMergeTextSegment(
                sourceBlockID: "\(block.id).header",
                kind: "panel.custom.header",
                attributedText: header,
                spacingAfter: 8
            )
            let children = try block.children.flatMap { try adapter.renderBlockAsDefault($0, context: context) }
            return [.mergeSegment(headerSegment)] + children
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.mentionKind.rawValue) { span, _, _, _ in
            let text = span.contractAttrString(for: "userId").map { "@\($0)" } ?? span.text
            return NSAttributedString(
                string: " \(text) ",
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.systemPink
                ]
            )
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.badgeKind.rawValue) { span, _, _, _ in
            let text = span.text
            return NSAttributedString(
                string: " [\(text)] ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.systemRed
                ]
            )
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.chipKind.rawValue) { span, _, _, _ in
            return NSAttributedString(
                string: " <\(span.text)> ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.systemTeal
                ]
            )
        }

        containerView.contractRenderAdapter = adapter
        do {
            try runtime.setInput(
                .markdown(
                    text: rendererCustomizationMarkdown,
                    documentID: "example.custom.renderer",
                    rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
                )
            )
            clearRenderErrorStatus()
        } catch {
            reportRenderError(error, markdown: rendererCustomizationMarkdown, source: "CustomRendererDemo.rendererCustomization")
        }
    }

    private func renderRuntimeCapabilityDemo() {
        containerView.contractRenderAdapter = makeAdapter()
        runtimeEventLogs.removeAll()
        runtimeEventLogView.text = "events:\n"
        loadRuntimeModel(documentID: runtimeDocumentID, mode: .capability, resetLogs: false)
        appendInfoLog("activate link 会返回 handled；copy 会在 5s 后自动 reset。")
    }

    private func renderPersistenceCapabilityDemo() {
        containerView.contractRenderAdapter = makeAdapter()
        runtimeEventLogs.removeAll()
        runtimeEventLogView.text = "events:\n"
        loadRuntimeModel(documentID: runtimePersistenceDocumentA, mode: .persistence, resetLogs: false)
        appendInfoLog("切到 Doc B 再切回 Doc A，可看到 snapshot 自动恢复。")
    }

    private func loadRuntimeModel(documentID: String, mode: RuntimeMode, resetLogs: Bool) {
        if resetLogs {
            runtimeEventLogs.removeAll()
            runtimeEventLogView.text = "events:\n"
        }
        do {
            try runtime.setInput(
                .renderModel(makeRuntimeDemoModel(documentID: documentID, mode: mode)),
                businessContext: [
                    "screen": .string("custom_renderer_demo"),
                    "mode": .string(mode.rawValue),
                    "activeDocument": .string(documentID),
                    "entry": .string("custom_runtime_demo")
                ]
            )
            currentRuntimeDocumentID = documentID
            runtimeMode = mode
            refreshRuntimeSnapshotLabel()
            clearRenderErrorStatus()
        } catch {
            reportRenderError(error, markdown: "runtime.renderModel[\(documentID)]", source: "CustomRendererDemo.runtime")
        }
    }

    private func makeAdapter() -> MarkdownContract.RenderModelUIKitAdapter {
        let adapter = ExampleMarkdownRuntime.makeExampleRenderAdapter()
        adapter.registerBlockMapper(forExtension: ExampleMarkdownRuntime.thinkKind.rawValue) { block, context, adapter in
            let thinkStateKey = block.contractAttrString(for: "id")
                ?? block.contractAttrString(for: "businessID")
                ?? block.id
            let collapsed = Self.uiStateBool(for: block, key: "collapsed") ?? false
            let toggleText = collapsed ? "展开" : "折叠"

            let header = NSMutableAttributedString(
                string: "Thinking（\(toggleText)）",
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
            header.addAttributes(
                [
                    .link: "xhs-think://\(thinkStateKey)",
                    .xhsInteractionNodeID: block.id,
                    .xhsInteractionNodeKind: block.kind.rawValue,
                    .xhsInteractionStateKey: thinkStateKey
                ],
                range: NSRange(location: 0, length: header.length)
            )

            var results: [MarkdownContract.BlockMappingResult] = [
                .mergeSegment(
                    adapter.makeMergeTextSegment(
                        sourceBlockID: "\(block.id).think.header",
                        kind: "think.header",
                        attributedText: header,
                        spacingAfter: collapsed ? 8 : 6,
                        metadata: block.metadata,
                        forceMergeBreakAfter: true
                    )
                )
            ]

            if !collapsed {
                let childResults = try block.children.flatMap {
                    try adapter.renderBlockAsDefault($0, context: context)
                }
                results.append(contentsOf: childResults.map(Self.tintThinkBody))
            }
            return results
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.citeKind.rawValue) { [weak self] span, _, _, _ in
            self?.makeCiteInline(span: span) ?? NSAttributedString(string: span.text)
        }
        return adapter
    }

    private static func uiStateBool(
        for block: MarkdownContract.RenderBlock,
        key: String
    ) -> Bool? {
        guard case let .object(uiState)? = block.metadata["uiState"],
              case let .bool(value)? = uiState[key] else {
            return nil
        }
        return value
    }

    private static func tintThinkBody(
        _ result: MarkdownContract.BlockMappingResult
    ) -> MarkdownContract.BlockMappingResult {
        switch result {
        case var .mergeSegment(segment):
            let tinted = NSMutableAttributedString(attributedString: segment.attributedText)
            if tinted.length > 0 {
                tinted.addAttribute(
                    .foregroundColor,
                    value: UIColor.secondaryLabel.withAlphaComponent(0.85),
                    range: NSRange(location: 0, length: tinted.length)
                )
            }
            segment.attributedText = tinted
            return .mergeSegment(segment)
        case .standalone:
            return result
        }
    }

    @objc
    private func toggleQuoteState() {
        dispatchRuntimeEvent(
            nodeID: runtimeQuoteNodeID,
            nodeKind: .blockQuote,
            action: "toggle"
        )
    }

    @objc
    private func triggerCopyState() {
        dispatchRuntimeEvent(
            nodeID: runtimeCodeNodeID,
            nodeKind: .codeBlock,
            action: "copy",
            payload: ["slot": .string("copyStatus")]
        )
    }

    @objc
    private func setCustomRuntimeState() {
        dispatchRuntimeEvent(
            nodeID: runtimeQuoteNodeID,
            nodeKind: .blockQuote,
            action: "set",
            payload: [
                "slot": .string("note"),
                "value": .string("custom.from.demo")
            ]
        )
    }

    @objc
    private func clearRuntimeEvents() {
        runtimeEventLogs.removeAll()
        runtimeEventLogView.text = "events:\n"
        refreshRuntimeSnapshotLabel()
    }

    @objc
    private func loadPersistenceDocA() {
        loadRuntimeModel(documentID: runtimePersistenceDocumentA, mode: .persistence, resetLogs: true)
        appendInfoLog("loaded Doc A")
    }

    @objc
    private func loadPersistenceDocB() {
        loadRuntimeModel(documentID: runtimePersistenceDocumentB, mode: .persistence, resetLogs: true)
        appendInfoLog("loaded Doc B")
    }

    @objc
    private func reloadCurrentRuntimeDoc() {
        loadRuntimeModel(documentID: currentRuntimeDocumentID, mode: runtimeMode, resetLogs: false)
        appendInfoLog("reloaded \(currentRuntimeDocumentID)")
    }

    @objc
    private func dispatchRuntimeActivate() {
        dispatchRuntimeEvent(
            nodeID: runtimeLinkNodeID,
            nodeKind: .link,
            action: "activate",
            payload: [
                "destination": .string("https://example.com/runtime"),
                "source": .string("manual.dispatch")
            ]
        )
    }

    private func dispatchRuntimeEvent(
        nodeID: String,
        nodeKind: MarkdownContract.NodeKind,
        action: String,
        payload: [String: MarkdownContract.Value] = [:]
    ) {
        let activeDocumentID = runtime.stateSnapshot.documentID
        runtime.dispatch(
            MarkdownEvent(
                documentID: activeDocumentID,
                nodeID: nodeID,
                nodeKind: nodeKind,
                stateKey: nodeID,
                action: action,
                payload: payload,
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )
        refreshRuntimeSnapshotLabel()
    }

    private func appendRuntimeEventLog(_ event: MarkdownEvent) {
        let summary = "[\(event.origin.rawValue)] doc=\(event.documentID) r\(event.revision) \(event.action) \(event.nodeKind.rawValue)#\(event.nodeID) stateKey=\(event.stateKey) payload=\(event.payload) associated=\(event.associatedData)"
        runtimeEventLogs.append(summary)
        let tail = runtimeEventLogs.suffix(12)
        runtimeEventLogView.text = (["events:"] + tail).joined(separator: "\n")
    }

    private func appendInfoLog(_ message: String) {
        runtimeEventLogs.append("[info] \(message)")
        let tail = runtimeEventLogs.suffix(12)
        runtimeEventLogView.text = (["events:"] + tail).joined(separator: "\n")
    }

    private func refreshRuntimeSnapshotLabel() {
        let snapshot = runtime.stateSnapshot
        let stateKeys = snapshot.nodeStates.keys.sorted()
        runtimeSnapshotLabel.text = """
        activeMode: \(runtimeMode.rawValue)
        activeDocument: \(currentRuntimeDocumentID)
        snapshot.documentID: \(snapshot.documentID)
        snapshot.revision: \(snapshot.revision)
        snapshot.stateKeys: \(stateKeys.joined(separator: ", "))
        """
    }

    private func makeRuntimeDemoModel(documentID: String, mode: RuntimeMode) -> MarkdownContract.RenderModel {
        let businessSuffix = mode.rawValue
        return MarkdownContract.RenderModel(
            documentId: documentID,
            blocks: [
                .init(
                    id: "runtime-intro",
                    kind: .paragraph,
                    inlines: [
                        .init(id: "runtime-text-1", kind: .text, text: "Runtime demo(\(mode.rawValue)): "),
                        .init(
                            id: runtimeLinkNodeID,
                            kind: .link,
                            text: "Activate Link",
                            metadata: [
                                "destination": .string("https://example.com/runtime"),
                                "businessID": .string("link.\(businessSuffix)"),
                                "tracking": .object([
                                    "source": .string("example.custom.renderer"),
                                    "channel": .string("runtime")
                                ])
                            ]
                        ),
                        .init(id: "runtime-text-2", kind: .text, text: " / copy code / toggle quote / custom inline")
                    ]
                ),
                .init(
                    id: "runtime-inline-ext",
                    kind: .paragraph,
                    inlines: [
                        .init(id: "runtime-inline-prefix", kind: .text, text: "Inline ext: "),
                        .init(
                            id: "runtime-inline-mention",
                            kind: ExampleMarkdownRuntime.mentionKind,
                            text: "@runtime-user",
                            metadata: [
                                "userId": .string("runtime-user"),
                                "businessID": .string("mention.\(businessSuffix)")
                            ]
                        ),
                        .init(id: "runtime-inline-mid", kind: .text, text: " / "),
                        .init(
                            id: "runtime-inline-cite",
                            kind: ExampleMarkdownRuntime.citeKind,
                            text: "runtime-ref",
                            metadata: [
                                "citeID": .string("runtime-ref-\(businessSuffix)"),
                                "businessID": .string("cite.inline.\(businessSuffix)")
                            ]
                        )
                    ]
                ),
                .init(
                    id: runtimeQuoteNodeID,
                    kind: .blockQuote,
                    children: [
                        .init(
                            id: "quote-inner",
                            kind: .paragraph,
                            inlines: [.init(id: "quote-inner-text", kind: .text, text: "This block can be collapsed via runtime.dispatch(toggle).")]
                        )
                    ],
                    metadata: [
                        "businessID": .string("quote.\(businessSuffix)"),
                        "tags": .array([.string("collapsible"), .string("stateful")])
                    ]
                ),
                .init(
                    id: runtimeCodeNodeID,
                    kind: .codeBlock,
                    metadata: [
                        "code": .string("print(\"runtime copy\")"),
                        "language": .string("swift"),
                        "businessID": .string("code.\(businessSuffix)"),
                        "meta": .object([
                            "owner": .string("runtime-demo"),
                            "version": .int(2)
                        ])
                    ]
                ),
                .init(
                    id: "runtime-cite-para",
                    kind: .paragraph,
                    inlines: [
                        .init(id: "runtime-cite-label", kind: .text, text: "Cite node: "),
                        .init(
                            id: "runtime-cite-inline",
                            kind: ExampleMarkdownRuntime.citeKind,
                            text: "ref-\(businessSuffix)",
                            metadata: [
                                "citeID": .string("ref-\(businessSuffix)"),
                                "businessID": .string("cite.\(businessSuffix)"),
                                "extra": .object([
                                    "category": .string("reference"),
                                    "score": .double(0.92)
                                ])
                            ]
                        )
                    ]
                )
            ]
        )
    }

    private func makeCiteInline(span: MarkdownContract.InlineSpan) -> NSAttributedString {
        let citeID = span.contractAttrString(for: "id")
            ?? span.contractAttrString(for: "citeID")
            ?? "unknown"
        let baseText = span.text.isEmpty ? "cite" : span.text
        let linkTarget = "xhs-cite://\(citeID.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? citeID)"

        let result = NSMutableAttributedString(
            string: baseText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
        )
        result.append(NSAttributedString(string: " "))

        let attachment = NSTextAttachment()
        attachment.image = Self.makeCiteBadgeImage(color: .systemOrange)
        attachment.bounds = CGRect(x: 0, y: -2, width: 10, height: 10)

        let badge = NSMutableAttributedString(attachment: attachment)
        if badge.length > 0 {
            badge.addAttributes(
                [
                    .link: linkTarget,
                    .xhsInteractionNodeID: span.id,
                    .xhsInteractionNodeKind: span.kind.rawValue,
                    .xhsInteractionStateKey: citeID
                ],
                range: NSRange(location: 0, length: badge.length)
            )
        }
        result.append(badge)
        return result
    }

    private static func makeCiteBadgeImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(color.cgColor)
            cg.move(to: CGPoint(x: 0, y: size.height))
            cg.addLine(to: CGPoint(x: size.width, y: 0))
            cg.addLine(to: CGPoint(x: size.width, y: size.height))
            cg.closePath()
            cg.fillPath()

            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(1.2)
            cg.setLineCap(.round)
            cg.move(to: CGPoint(x: 4, y: 7))
            cg.addLine(to: CGPoint(x: 7, y: 4))
            cg.strokePath()

            cg.move(to: CGPoint(x: 6.7, y: 4))
            cg.addLine(to: CGPoint(x: 7, y: 5.8))
            cg.strokePath()

            cg.move(to: CGPoint(x: 7, y: 4.3))
            cg.addLine(to: CGPoint(x: 5.2, y: 4))
            cg.strokePath()
        }
    }

    private func reportRenderError(_ error: Error, markdown: String, source: String) {
        latestRenderErrorPayload = buildErrorPayload(error: error, markdown: markdown, source: source)
        statusLabel.text = "渲染失败，点此复制错误信息"
        statusLabel.isHidden = false
        if let payload = latestRenderErrorPayload {
            print(payload)
        }
    }

    private func clearRenderErrorStatus() {
        latestRenderErrorPayload = nil
        statusLabel.isHidden = true
        statusLabel.text = nil
    }

    private func buildErrorPayload(error: Error, markdown: String, source: String) -> String {
        var lines: [String] = []
        lines.append("=== XHSMarkdownKit Example Render Error ===")
        lines.append("source: \(source)")
        lines.append("time: \(ISO8601DateFormatter().string(from: Date()))")
        if let modelError = error as? MarkdownContract.ModelError {
            lines.append("code: \(modelError.code)")
            if let path = modelError.path {
                lines.append("path: \(path)")
            }
            lines.append("message: \(modelError.message)")
        } else {
            lines.append("error: \(String(reflecting: error))")
        }
        lines.append("--- markdown begin ---")
        lines.append(markdown)
        lines.append("--- markdown end ---")
        return lines.joined(separator: "\n")
    }

}

final class CustomCodeBlockView: UIView, RevealLayoutAnimatableView {

    private let languageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        return label
    }()

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()

    private var fullCode: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        contentStack.addArrangedSubview(languageLabel)
        contentStack.addArrangedSubview(codeLabel)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(code: String, language: String, maxWidth: CGFloat) {
        fullCode = code
        languageLabel.text = language.uppercased()
        codeLabel.preferredMaxLayoutWidth = max(0, maxWidth - 24)
        codeLabel.text = code
        invalidateIntrinsicContentSize()
    }

    func applyRevealState(_ state: RevealState) {
        let clamped = max(0, min(state.displayedUnits, fullCode.count))
        codeLabel.text = String(fullCode.prefix(clamped))
        invalidateRevealLayout()
    }
}
