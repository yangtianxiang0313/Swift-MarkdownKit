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

    private lazy var containerView: MarkdownContainerView = {
        ExampleMarkdownRuntime.makeConfiguredContainer(theme: .default)
    }()

    // MARK: - Data

    private let descriptions = [
        "使用默认渲染器渲染 Markdown 内容。",
        "使用自定义渲染器覆盖代码块的默认样式。",
        "使用 Contract 链路解析 directive / HTML 标签，并替换 block/inline 的渲染实现。",
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

    @Card(title: "推荐卡片") {
    这是 directive 节点，渲染时被替换成自定义 UI。
    }

    正文里支持 inline HTML：发布状态 <badge text="new" /> 与 <badge text="hot" />。

    <spotlight type="warning">
    这是 html block 节点，也被替换成自定义 UI。
    </spotlight>
    """

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
        containerView.contractRenderAdapter = MarkdownContract.RenderModelUIKitAdapter()
        do {
            try containerView.setContractMarkdown(
                demoMarkdown,
                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
            )
        } catch {
            descriptionLabel.text = "Contract 渲染失败：\(error.localizedDescription)"
        }
    }

    private func renderCustomCodeBlockDemo() {
        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerBlockRenderer(for: .codeBlock) { block, _, adapter in
            let code = block.contractAttrString(for: "code") ?? ""
            let language = block.contractAttrString(for: "language") ?? "text"

            return [adapter.makeCustomViewNode(
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
                reveal: { view, displayedUnits in
                    guard let codeView = view as? CustomCodeBlockView else { return }
                    codeView.reveal(upTo: displayedUnits)
                }
            )]
        }

        containerView.contractRenderAdapter = adapter
        do {
            try containerView.setContractMarkdown(
                demoMarkdown,
                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
            )
        } catch {
            descriptionLabel.text = "Contract 渲染失败：\(error.localizedDescription)"
        }
    }

    private func renderContractCustomElementDemo() {
        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerBlockRenderer(forExtension: ExampleMarkdownRuntime.cardKind.rawValue) { block, _, _ in
            let title = block.contractAttrString(for: "title") ?? "Card"
            let text = "Contract Card\n\(title)"
            return [Self.makeCalloutNode(
                nodeID: block.id,
                text: text,
                color: .systemBlue
            )]
        }
        adapter.registerBlockRenderer(forExtension: ExampleMarkdownRuntime.spotlightKind.rawValue) { block, _, _ in
            let type = block.contractAttrString(for: "type") ?? "info"
            let text = "HTML Spotlight (\(type.uppercased()))"
            return [Self.makeCalloutNode(
                nodeID: block.id,
                text: text,
                color: .systemOrange
            )]
        }
        adapter.registerInlineRenderer(forExtension: ExampleMarkdownRuntime.badgeKind.rawValue) { span, _, _, _ in
            let text = span.contractAttrString(for: "text") ?? "badge"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.systemPink
            ]
            return NSAttributedString(string: " \(text.uppercased()) ", attributes: attrs)
        }

        containerView.contractRenderAdapter = adapter

        do {
            try containerView.setContractMarkdown(
                contractCustomMarkdown,
                rewritePipeline: ExampleMarkdownRuntime.makeRewritePipeline()
            )
        } catch {
            descriptionLabel.text = "Contract 渲染失败：\(error.localizedDescription)"
        }
    }

    private static func makeCalloutNode(
        nodeID: String,
        text: String,
        color: UIColor
    ) -> RenderScene.Node {
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

        return RenderScene.Node(
            id: nodeID,
            kind: "paragraph",
            component: TextSceneComponent(attributedText: attributed),
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
