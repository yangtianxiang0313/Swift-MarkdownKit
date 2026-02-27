import UIKit
import XHSMarkdownKit

/// 主题切换演示页面
/// 展示不同预设主题的效果，以及自定义主题配置
class ThemeSwitchViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = true
        return sv
    }()
    
    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 24
        sv.alignment = .fill
        return sv
    }()
    
    private lazy var themeSelector: UISegmentedControl = {
        let control = UISegmentedControl(items: ["默认", "富文本", "紧凑", "可读"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var containerView: MarkdownContainerView = {
        let engine = MarkdownRenderEngine.makeDefault()
        let view = MarkdownContainerView(engine: engine)
        view.onContentHeightChanged = { [weak self] _ in
            self?.updateContainerHeight()
        }
        return view
    }()
    
    private var containerHeightConstraint: NSLayoutConstraint?
    
    private lazy var customizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("自定义主题设置", for: .normal)
        button.addTarget(self, action: #selector(showCustomizePanel), for: .touchUpInside)
        return button
    }()
    
    // 自定义设置面板
    private lazy var customPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 12
        view.isHidden = true
        return view
    }()
    
    private lazy var fontSizeSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 12
        slider.maximumValue = 24
        slider.value = 15
        slider.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var fontSizeLabel: UILabel = {
        let label = UILabel()
        label.text = "字号: 15"
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var lineHeightSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 18
        slider.maximumValue = 40
        slider.value = 25
        slider.addTarget(self, action: #selector(lineHeightChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var lineHeightLabel: UILabel = {
        let label = UILabel()
        label.text = "行高: 25"
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var spacingSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 8
        slider.maximumValue = 40
        slider.value = 16
        slider.addTarget(self, action: #selector(spacingChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var spacingLabel: UILabel = {
        let label = UILabel()
        label.text = "段落间距: 16"
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var colorButtons: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        
        let colors: [(String, UIColor)] = [
            ("黑色", .label),
            ("蓝色", .systemBlue),
            ("紫色", .systemPurple),
            ("绿色", .systemGreen)
        ]
        
        for (title, color) in colors {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(color, for: .normal)
            button.tag = colors.firstIndex(where: { $0.1 == color }) ?? 0
            button.addTarget(self, action: #selector(colorSelected(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        
        return stack
    }()
    
    // MARK: - Properties
    
    private var currentTheme: MarkdownTheme = .default
    private var customFontSize: CGFloat = 15
    private var customLineHeight: CGFloat = 25
    private var customSpacing: CGFloat = 16
    private var customBodyColor: UIColor = .label
    
    private let sampleMarkdown = """
    # 主题预览
    
    这是一段示例文本，用于展示不同主题的渲染效果。
    
    ## 文本样式
    
    支持 **加粗**、*斜体*、~~删除线~~ 和 `行内代码` 等样式。
    
    ## 列表
    
    - 第一项
    - 第二项
      - 嵌套项
    - 第三项
    
    ## 引用
    
    > 这是一段引用文本。
    > 可以包含多行内容。
    
    ## 代码块
    
    ```swift
    let theme = MarkdownTheme.default
    let result = MarkdownKit.render(markdown, theme: theme)
    ```
    
    ## 链接
    
    访问 [XHSMarkdownKit](https://example.com) 了解更多。
    
    ---
    
    *切换上方的主题选项查看不同效果*
    """
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        renderWithCurrentTheme()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderWithCurrentTheme()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "主题切换"
        view.backgroundColor = .systemBackground
        
        // 主滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 添加内容
        let themeSelectorContainer = createSectionView(title: "预设主题", content: themeSelector)
        stackView.addArrangedSubview(themeSelectorContainer)
        
        stackView.addArrangedSubview(customizeButton)
        
        setupCustomPanel()
        stackView.addArrangedSubview(customPanel)
        
        let previewContainer = createSectionView(title: "预览", content: containerView)
        stackView.addArrangedSubview(previewContainer)
    }
    
    private func setupCustomPanel() {
        let panelStack = UIStackView()
        panelStack.axis = .vertical
        panelStack.spacing = 16
        panelStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panelStack.isLayoutMarginsRelativeArrangement = true
        
        // 字号设置
        let fontSizeStack = UIStackView(arrangedSubviews: [fontSizeLabel, fontSizeSlider])
        fontSizeStack.axis = .vertical
        fontSizeStack.spacing = 8
        panelStack.addArrangedSubview(fontSizeStack)
        
        // 行高设置
        let lineHeightStack = UIStackView(arrangedSubviews: [lineHeightLabel, lineHeightSlider])
        lineHeightStack.axis = .vertical
        lineHeightStack.spacing = 8
        panelStack.addArrangedSubview(lineHeightStack)
        
        // 段落间距设置
        let spacingStack = UIStackView(arrangedSubviews: [spacingLabel, spacingSlider])
        spacingStack.axis = .vertical
        spacingStack.spacing = 8
        panelStack.addArrangedSubview(spacingStack)
        
        // 颜色选择
        let colorLabel = UILabel()
        colorLabel.text = "文本颜色"
        colorLabel.font = .systemFont(ofSize: 14)
        let colorStack = UIStackView(arrangedSubviews: [colorLabel, colorButtons])
        colorStack.axis = .vertical
        colorStack.spacing = 8
        panelStack.addArrangedSubview(colorStack)
        
        customPanel.addSubview(panelStack)
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panelStack.topAnchor.constraint(equalTo: customPanel.topAnchor),
            panelStack.leadingAnchor.constraint(equalTo: customPanel.leadingAnchor),
            panelStack.trailingAnchor.constraint(equalTo: customPanel.trailingAnchor),
            panelStack.bottomAnchor.constraint(equalTo: customPanel.bottomAnchor)
        ])
    }
    
    private func createSectionView(title: String, content: UIView) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        
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
        
        // 如果是 containerView，添加高度约束
        if content === containerView {
            containerHeightConstraint = content.heightAnchor.constraint(equalToConstant: 100)
            containerHeightConstraint?.isActive = true
        }
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func themeChanged() {
        switch themeSelector.selectedSegmentIndex {
        case 0:
            currentTheme = .default
        case 1:
            currentTheme = .richtext
        case 2:
            currentTheme = .compact
        case 3:
            currentTheme = .readable
        default:
            currentTheme = .default
        }
        
        // 更新滑块值
        fontSizeSlider.value = Float(currentTheme.body.font.pointSize)
        lineHeightSlider.value = Float(currentTheme.body.lineHeight)
        spacingSlider.value = Float(currentTheme.spacing.paragraph)
        
        updateLabels()
        renderWithCurrentTheme()
    }
    
    @objc private func showCustomizePanel() {
        UIView.animate(withDuration: 0.3) {
            self.customPanel.isHidden.toggle()
        }
    }
    
    @objc private func fontSizeChanged() {
        customFontSize = CGFloat(fontSizeSlider.value)
        fontSizeLabel.text = "字号: \(Int(customFontSize))"
        applyCustomSettings()
    }
    
    @objc private func lineHeightChanged() {
        customLineHeight = CGFloat(lineHeightSlider.value)
        lineHeightLabel.text = "行高: \(Int(customLineHeight))"
        applyCustomSettings()
    }
    
    @objc private func spacingChanged() {
        customSpacing = CGFloat(spacingSlider.value)
        spacingLabel.text = "段落间距: \(Int(customSpacing))"
        applyCustomSettings()
    }
    
    @objc private func colorSelected(_ sender: UIButton) {
        let colors: [UIColor] = [.label, .systemBlue, .systemPurple, .systemGreen]
        customBodyColor = colors[sender.tag]
        applyCustomSettings()
    }
    
    private func updateLabels() {
        fontSizeLabel.text = "字号: \(Int(fontSizeSlider.value))"
        lineHeightLabel.text = "行高: \(Int(lineHeightSlider.value))"
        spacingLabel.text = "段落间距: \(Int(spacingSlider.value))"
    }
    
    private func applyCustomSettings() {
        currentTheme.body.font = .systemFont(ofSize: customFontSize)
        currentTheme.body.lineHeight = customLineHeight
        currentTheme.spacing.paragraph = customSpacing
        currentTheme.body.color = customBodyColor
        
        renderWithCurrentTheme()
    }
    
    // MARK: - Rendering
    
    private func renderWithCurrentTheme() {
        let result = MarkdownKit.render(sampleMarkdown, theme: currentTheme)
        containerView.apply(result)
        
        updateContainerHeight()
    }
    
    private func updateContainerHeight() {
        // 更新高度约束
        containerHeightConstraint?.constant = containerView.contentHeight
        
        // 强制更新布局
        view.layoutIfNeeded()
    }
}
