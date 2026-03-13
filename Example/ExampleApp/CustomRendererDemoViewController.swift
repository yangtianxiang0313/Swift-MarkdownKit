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
        MarkdownContainerView(theme: .default)
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
            try containerView.setContractMarkdown(demoMarkdown)
        } catch {
            descriptionLabel.text = "Contract 渲染失败：\(error.localizedDescription)"
        }
    }

    private func renderCustomCodeBlockDemo() {
        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerBlockRenderer(for: .codeBlock) { block, _, _ in
            let code = block.contractAttrString(for: "code") ?? ""
            let language = block.contractAttrString(for: "language") ?? "text"
            let content = CustomCodeFragmentContent(code: code, language: language)

            return [ContractViewFragment(
                fragmentId: block.id,
                nodeType: .codeBlock,
                reuseIdentifier: ReuseIdentifier(rawValue: "contract.customCodeBlock"),
                content: content,
                totalContentLength: code.count,
                makeView: { CustomCodeBlockView() },
                configure: { view in
                    guard let codeView = view as? CustomCodeBlockView else { return }
                    codeView.configure(code: code, language: language)
                }
            )]
        }
        containerView.contractRenderAdapter = adapter
        do {
            try containerView.setContractMarkdown(demoMarkdown)
        } catch {
            descriptionLabel.text = "Contract 渲染失败：\(error.localizedDescription)"
        }
    }

    private func renderContractCustomElementDemo() {
        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerBlockRenderer(forCustomElement: "Card") { block, _, _ in
            let title = block.contractAttrString(for: "title") ?? "Card"
            let text = "🧩 Contract Card\n\(title)"
            return [Self.makeCalloutFragment(
                fragmentId: block.id,
                text: text,
                color: .systemBlue
            )]
        }
        adapter.registerBlockRenderer(forCustomElement: "spotlight") { block, _, _ in
            let type = block.contractAttrString(for: "type") ?? "info"
            let text = "💡 HTML Spotlight (\(type.uppercased()))"
            return [Self.makeCalloutFragment(
                fragmentId: block.id,
                text: text,
                color: .systemOrange
            )]
        }
        adapter.registerInlineRenderer(forCustomElement: "badge") { span, _, _, _ in
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
            try containerView.setContractMarkdown(contractCustomMarkdown)
        } catch {
            descriptionLabel.text = "Contract 渲染失败：\(error.localizedDescription)"
        }
    }

    private static func makeCalloutFragment(
        fragmentId: String,
        text: String,
        color: UIColor
    ) -> RenderFragment {
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

        return ContractTextFragment(
            fragmentId: fragmentId,
            nodeType: .paragraph,
            reuseIdentifier: .contractTextView,
            attributedString: attributed,
            makeView: { ContractTextView() },
            configure: { view, _ in
                guard let textView = view as? ContractTextView else { return }
                textView.configure(attributedString: attributed, indent: 0)
            }
        )
    }
}

// MARK: - Contract Custom Content

private struct CustomCodeFragmentContent: FragmentContent {
    let code: String
    let language: String

    func isEqual(to other: any FragmentContent) -> Bool {
        guard let rhs = other as? CustomCodeFragmentContent else { return false }
        return code == rhs.code && language == rhs.language
    }
}

class CustomCodeBlockView: UIView, HeightEstimatable, StreamableContent {

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

    private var fullCode: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        addSubview(languageLabel)
        addSubview(codeLabel)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(code: String, language: String) {
        fullCode = code
        languageLabel.text = language.uppercased()
        codeLabel.text = code
    }

    func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        let codeWidth = maxWidth - 24
        let clamped = max(0, min(atDisplayedLength, fullCode.count))
        let displayed = String(fullCode.prefix(clamped))
        let size = displayed.boundingRect(
            with: CGSize(width: codeWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: codeLabel.font as Any],
            context: nil
        )
        return ceil(size.height) + 50
    }

    func reveal(upTo length: Int) {
        let clamped = max(0, min(length, fullCode.count))
        codeLabel.text = String(fullCode.prefix(clamped))
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        languageLabel.frame = CGRect(x: 12, y: 8, width: bounds.width - 24, height: 18)
        codeLabel.frame = CGRect(x: 12, y: 34, width: bounds.width - 24, height: bounds.height - 46)
    }
}

private extension MarkdownContract.RenderBlock {
    var contractAttrs: [String: MarkdownContract.Value] {
        guard let attrs = metadata["attrs"], case let .object(map) = attrs else {
            return [:]
        }
        return map
    }

    func contractAttrString(for key: String) -> String? {
        if let value = contractAttrs[key], case let .string(text) = value {
            return text
        }
        if let nested = contractAttrs["attributes"], case let .object(map) = nested,
           let value = map[key], case let .string(text) = value {
            return text
        }
        return nil
    }
}

private extension MarkdownContract.InlineSpan {
    var contractAttrs: [String: MarkdownContract.Value] {
        guard let attrs = metadata["attrs"], case let .object(map) = attrs else {
            return [:]
        }
        return map
    }

    func contractAttrString(for key: String) -> String? {
        if let value = contractAttrs[key], case let .string(text) = value {
            return text
        }
        if let nested = contractAttrs["attributes"], case let .object(map) = nested,
           let value = map[key], case let .string(text) = value {
            return text
        }
        return nil
    }
}
