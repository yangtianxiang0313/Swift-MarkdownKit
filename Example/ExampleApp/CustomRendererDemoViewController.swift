import UIKit
import XHSMarkdownKit

class CustomRendererDemoViewController: UIViewController {

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
        let control = UISegmentedControl(items: ["默认", "自定义代码块", "Contract节点"])
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

    private lazy var containerView: MarkdownContainerView = {
        ExampleMarkdownRuntime.makeConfiguredContainer(theme: .default)
    }()

    // MARK: - Data

    private let descriptions = [
        "使用默认渲染器渲染 Markdown 内容。",
        "使用自定义渲染器覆盖代码块的默认样式。",
        "使用 Contract 链路解析扩展节点（block leaf/container + inline leaf/container），并替换 block/inline 的渲染实现。",
    ]

    private let demoMarkdown = """
    # 架构演示

    这是一段普通文本，展示**加粗**和*斜体*效果。

    ## 代码块

    ```swift
    func hello() {
        print("Hello!")
    }
    ```

    ## 列表

    1. 第一项
    2. 第二项
    3. 第三项

    - 无序列表项 A
    - 无序列表项 B

    > 这是一段引用文本

    ---

    结束！
    """

    private let contractCustomMarkdown = """
    # Contract 自定义节点演示

    @Callout(title: "这是 block leaf")

    @Tabs {
    - iOS
    - Android
    - Web
    }

    正文里支持 inline HTML：
    <mention userId="new-user" />
    ~~已删除~~ 文本和 <spoiler text="剧透内容" /> 都能走 Contract 渲染。
    """
    private var latestRenderErrorPayload: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        switch index {
        case 0:
            renderDefaultDemo()
        case 1:
            renderCustomCodeBlockDemo()
        case 2:
            renderContractCustomElementDemo()
        default:
            break
        }
    }

    private func renderDefaultDemo() {
        containerView.contractRenderAdapter = makeAdapter()
        do {
            try containerView.setContractMarkdown(
                demoMarkdown,
                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
            )
            clearRenderErrorStatus()
        } catch {
            reportRenderError(error, markdown: demoMarkdown, source: "CustomRendererDemo.default")
        }
    }

    private func renderCustomCodeBlockDemo() {
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
                },
                reveal: { view, state in
                    guard let codeView = view as? CustomCodeBlockView else { return }
                    codeView.reveal(upTo: state.displayedUnits)
                }
            )
            return [.standalone(node)]
        }

        containerView.contractRenderAdapter = adapter
        do {
            try containerView.setContractMarkdown(
                demoMarkdown,
                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
            )
            clearRenderErrorStatus()
        } catch {
            reportRenderError(error, markdown: demoMarkdown, source: "CustomRendererDemo.customCodeBlock")
        }
    }

    private func renderContractCustomElementDemo() {
        let adapter = makeAdapter()
        adapter.registerBlockMapper(forExtension: ExampleMarkdownRuntime.calloutKind.rawValue) { block, _, adapter in
            let title = block.contractAttrString(for: "title") ?? "Callout"
            let text = "Block Leaf: \(title)"
            let segment = Self.makeCalloutSegment(
                adapter: adapter,
                blockID: block.id,
                text: text,
                color: .systemBlue
            )
            return [.mergeSegment(segment)]
        }
        adapter.registerBlockMapper(forExtension: ExampleMarkdownRuntime.tabsKind.rawValue) { block, context, adapter in
            let header = Self.makeCalloutSegment(
                adapter: adapter,
                blockID: "\(block.id).tabs.header",
                text: "Block Container: Tabs",
                color: .systemOrange
            )
            let children = try block.children.flatMap { try adapter.renderBlockAsDefault($0, context: context) }
            return [.mergeSegment(header)] + children
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.mentionKind.rawValue) { span, _, _, _ in
            let text = span.contractAttrString(for: "userId").map { "@\($0)" } ?? span.text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.systemPink
            ]
            return NSAttributedString(string: " \(text) ", attributes: attrs)
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.spoilerKind.rawValue) { span, _, _, _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.systemIndigo
            ]
            return NSAttributedString(string: " [SPOILER] \(span.text) ", attributes: attrs)
        }

        containerView.contractRenderAdapter = adapter

        do {
            try containerView.setContractMarkdown(
                contractCustomMarkdown,
                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
            )
            clearRenderErrorStatus()
        } catch {
            reportRenderError(error, markdown: contractCustomMarkdown, source: "CustomRendererDemo.contractNodes")
        }
    }

    private func makeAdapter() -> MarkdownContract.RenderModelUIKitAdapter {
        MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )
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

    private static func makeCalloutSegment(
        adapter: MarkdownContract.RenderModelUIKitAdapter,
        blockID: String,
        text: String,
        color: UIColor
    ) -> MarkdownContract.MergeTextSegment {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        return adapter.makeMergeTextSegment(
            sourceBlockID: blockID,
            kind: "paragraph",
            attributedText: attributed,
            spacingAfter: 12
        )
    }
}

final class CustomCodeBlockView: UIView {

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

    func reveal(upTo length: Int) {
        let clamped = max(0, min(length, fullCode.count))
        codeLabel.text = String(fullCode.prefix(clamped))
    }
}
