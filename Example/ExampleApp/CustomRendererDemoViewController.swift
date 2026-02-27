import UIKit
import XHSMarkdownKit
import XYMarkdown

/// 自定义渲染器演示页面
/// 展示如何使用 V2 架构的自定义渲染器
class CustomRendererDemoViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        return sv
    }()
    
    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 24
        sv.alignment = .fill
        return sv
    }()
    
    private lazy var demoSelector: UISegmentedControl = {
        let control = UISegmentedControl(items: ["默认", "自定义代码块"])
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
        let engine = MarkdownRenderEngine.makeDefault()
        let view = MarkdownContainerView(engine: engine)
        return view
    }()
    
    // MARK: - Properties
    
    private let descriptions = [
        "使用默认渲染器渲染 Markdown 内容。",
        "使用自定义渲染器覆盖代码块的默认样式，添加圆角、边框和自定义背景色。",
    ]
    
    private let demoMarkdown = """
    # V2 架构演示
    
    这是一段普通文本，展示**加粗**和*斜体*效果。
    
    ## 代码块
    
    ```swift
    func hello() {
        print("Hello, V2!")
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
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        renderDemo(index: 0)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "自定义渲染器 (V2)"
        
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
        default:
            break
        }
    }
    
    private func renderDefaultDemo() {
        // 使用 MarkdownKit 渲染
        let result = MarkdownKit.render(demoMarkdown, theme: .default)
        containerView.apply(result)
    }
    
    private func renderCustomCodeBlockDemo() {
        // 创建自定义注册表
        let registry = RendererRegistry.makeDefault()
        
        // 注册自定义代码块渲染器
        registry.register(CustomCodeBlockRenderer(), for: .codeBlock)
        
        // 使用自定义引擎
        let stateStore = FragmentStateStore()
        let engine = MarkdownRenderEngine(
            registry: registry,
            theme: .default,
            configuration: .default,
            stateStore: stateStore
        )
        let result = engine.render(demoMarkdown)
        containerView.apply(result)
    }
}

// MARK: - Custom Code Block Renderer (V2 API)

/// 自定义代码块渲染器 (V2)
final class CustomCodeBlockRenderer: NodeRenderer {
    
    func render(node: Markup, context: RenderContext, childRenderer: ChildRenderer) -> [RenderFragment] {
        guard let codeBlock = node as? CodeBlock else { return [] }
        
        let language = codeBlock.language ?? "text"
        let code = codeBlock.code
        
        let fragment = ViewFragment(
            fragmentId: "custom-codeblock-\(context[IndexInParentKey.self])",
            nodeType: .codeBlock,
            reuseIdentifier: .customCodeBlock,
            estimatedSize: CGSize(width: context.maxWidth, height: 200),
            context: .init(),
            content: (code: code, language: language),
            makeView: {
                CustomCodeBlockView()
            },
            configure: { view, content, _ in
                if let codeView = view as? CustomCodeBlockView,
                   let data = content as? (code: String, language: String) {
                    codeView.configure(code: data.code, language: data.language)
                }
            }
        )
        
        return [fragment]
    }
}

/// 自定义代码块视图
class CustomCodeBlockView: UIView {
    
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        addSubview(languageLabel)
        addSubview(codeLabel)
        
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            languageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            languageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            languageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            codeLabel.topAnchor.constraint(equalTo: languageLabel.bottomAnchor, constant: 8),
            codeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            codeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            codeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func configure(code: String, language: String) {
        languageLabel.text = language.isEmpty ? "Code" : language.uppercased()
        codeLabel.text = code
    }
    
    override var intrinsicContentSize: CGSize {
        let labelSize = codeLabel.intrinsicContentSize
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: labelSize.height + 50
        )
    }
}
