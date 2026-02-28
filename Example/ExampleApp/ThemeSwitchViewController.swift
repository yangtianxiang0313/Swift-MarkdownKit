import UIKit
import XHSMarkdownKit

class ThemeSwitchViewController: UIViewController, MarkdownContainerViewDelegate {

    // MARK: - UI

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
        let control = UISegmentedControl(items: ["默认", "自定义"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        return control
    }()

    private lazy var containerView: MarkdownContainerView = {
        let view = MarkdownContainerView(theme: .default)
        view.delegate = self
        return view
    }()

    private var containerHeightConstraint: NSLayoutConstraint?

    private lazy var customizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("自定义主题设置", for: .normal)
        button.addTarget(self, action: #selector(showCustomizePanel), for: .touchUpInside)
        return button
    }()

    private lazy var customPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 12
        view.isHidden = true
        return view
    }()

    private lazy var fontSizeSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 12; slider.maximumValue = 24; slider.value = 15
        slider.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)
        return slider
    }()

    private lazy var fontSizeLabel: UILabel = {
        let l = UILabel(); l.text = "字号: 15"; l.font = .systemFont(ofSize: 14); return l
    }()

    private lazy var lineHeightSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 18; slider.maximumValue = 40; slider.value = 25
        slider.addTarget(self, action: #selector(lineHeightChanged), for: .valueChanged)
        return slider
    }()

    private lazy var lineHeightLabel: UILabel = {
        let l = UILabel(); l.text = "行高: 25"; l.font = .systemFont(ofSize: 14); return l
    }()

    private lazy var spacingSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 8; slider.maximumValue = 40; slider.value = 16
        slider.addTarget(self, action: #selector(spacingChanged), for: .valueChanged)
        return slider
    }()

    private lazy var spacingLabel: UILabel = {
        let l = UILabel(); l.text = "段落间距: 16"; l.font = .systemFont(ofSize: 14); return l
    }()

    // MARK: - Properties

    private var currentTheme: MarkdownTheme = .default

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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderWithCurrentTheme()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "主题切换"
        view.backgroundColor = .systemBackground

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

        panelStack.addArrangedSubview(UIStackView(arrangedSubviews: [fontSizeLabel, fontSizeSlider]).then { $0.axis = .vertical; $0.spacing = 8 })
        panelStack.addArrangedSubview(UIStackView(arrangedSubviews: [lineHeightLabel, lineHeightSlider]).then { $0.axis = .vertical; $0.spacing = 8 })
        panelStack.addArrangedSubview(UIStackView(arrangedSubviews: [spacingLabel, spacingSlider]).then { $0.axis = .vertical; $0.spacing = 8 })

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

        if content === containerView {
            containerHeightConstraint = content.heightAnchor.constraint(equalToConstant: 100)
            containerHeightConstraint?.isActive = true
        }

        return container
    }

    // MARK: - Actions

    @objc private func themeChanged() {
        currentTheme = themeSelector.selectedSegmentIndex == 0 ? .default : currentTheme
        fontSizeSlider.value = Float(currentTheme.body.font.pointSize)
        lineHeightSlider.value = Float(currentTheme.body.lineHeight)
        spacingSlider.value = Float(currentTheme.spacing.paragraph)
        renderWithCurrentTheme()
    }

    @objc private func showCustomizePanel() {
        UIView.animate(withDuration: 0.3) { self.customPanel.isHidden.toggle() }
    }

    @objc private func fontSizeChanged() {
        fontSizeLabel.text = "字号: \(Int(fontSizeSlider.value))"
        applyCustomSettings()
    }

    @objc private func lineHeightChanged() {
        lineHeightLabel.text = "行高: \(Int(lineHeightSlider.value))"
        applyCustomSettings()
    }

    @objc private func spacingChanged() {
        spacingLabel.text = "段落间距: \(Int(spacingSlider.value))"
        applyCustomSettings()
    }

    private func applyCustomSettings() {
        currentTheme.body.font = .systemFont(ofSize: CGFloat(fontSizeSlider.value))
        currentTheme.body.lineHeight = CGFloat(lineHeightSlider.value)
        currentTheme.spacing.paragraph = CGFloat(spacingSlider.value)
        renderWithCurrentTheme()
    }

    // MARK: - Rendering

    private func renderWithCurrentTheme() {
        containerView.theme = currentTheme
        containerView.setText(sampleMarkdown)
    }

    private func updateContainerHeight() {
        containerHeightConstraint?.constant = containerView.contentHeight
        view.layoutIfNeeded()
    }

    // MARK: - MarkdownContainerViewDelegate

    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        updateContainerHeight()
    }
}

private extension UIStackView {
    @discardableResult
    func then(_ configure: (UIStackView) -> Void) -> UIStackView {
        configure(self)
        return self
    }
}
