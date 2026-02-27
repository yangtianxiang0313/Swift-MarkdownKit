import Foundation
import UIKit

// MARK: - CodeBlockView

/// 代码块视图
/// 现代化设计，支持横向和纵向滚动
/// 支持最大高度限制，超出部分可滚动查看
public final class CodeBlockView: UIView, FragmentView, FragmentEventReporting, StreamableContent, SimpleStreamableContent {

    public var totalLength: Int { (currentCode as NSString).length }
    
    public typealias Content = CodeBlockContent
    
    // MARK: - UI Elements
    
    /// 头部栏（语言 + 复制按钮）
    private let headerBar = UIView()
    
    /// 语言标签（带圆角背景）
    private let languageBadge = UIView()
    private let languageLabel = UILabel()
    
    /// 复制按钮（初始文案和图标在 applyTheme 中设置）
    private let copyButton: UIButton = UIButton(type: .system)
    
    /// 代码滚动视图
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator = true
        sv.alwaysBounceHorizontal = false
        sv.alwaysBounceVertical = false
        sv.indicatorStyle = .default
        return sv
    }()
    
    /// 代码内容 Label（使用 Label 而非 TextView 以获得更好的性能）
    private let codeLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = CodeBlockConstants.unlimitedLines
        label.backgroundColor = .clear
        return label
    }()
    
    /// 主容器
    private let containerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    // MARK: - State
    
    private var currentFragmentId: String = ""
    private var currentCode: String = ""
    private var currentLanguage: String = ""
    private var theme: MarkdownTheme = .default
    
    // MARK: - FragmentEventReporting
    
    public var onEvent: ((FragmentEvent) -> Void)?
    
    // MARK: - Computed Properties (from theme)
    
    private var headerHeight: CGFloat { theme.code.block.header.height }
    private var headerStyle: MarkdownTheme.CodeBlockHeaderStyle { theme.code.block.header }
    private var badgeStyle: MarkdownTheme.BadgeStyle { theme.code.block.header.badge }
    private var buttonStyle: MarkdownTheme.ButtonStyle { theme.code.block.header.copyButton }
    private var blockStyle: MarkdownTheme.CodeBlockStyle { theme.code.block }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(containerView)
        
        containerView.addSubview(headerBar)
        headerBar.addSubview(languageBadge)
        languageBadge.addSubview(languageLabel)
        headerBar.addSubview(copyButton)
        
        containerView.addSubview(scrollView)
        scrollView.addSubview(codeLabel)
        
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        applyTheme()
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let padding = blockStyle.padding
        
        containerView.frame = bounds
        
        // 头部栏
        headerBar.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: headerHeight
        )
        headerBar.backgroundColor = blockStyle.backgroundColor.darker(by: headerStyle.darkenRatio)
        
        // 语言标签
        if !currentLanguage.isEmpty {
            let badgeWidth = languageLabel.intrinsicContentSize.width + badgeStyle.horizontalPadding * 2
            languageBadge.frame = CGRect(
                x: padding.left,
                y: (headerHeight - badgeStyle.height) / 2,
                width: badgeWidth,
                height: badgeStyle.height
            )
            languageLabel.frame = CGRect(
                x: badgeStyle.horizontalPadding,
                y: (badgeStyle.height - languageLabel.intrinsicContentSize.height) / 2,
                width: badgeWidth - badgeStyle.horizontalPadding * 2,
                height: languageLabel.intrinsicContentSize.height
            )
            languageBadge.isHidden = false
        } else {
            languageBadge.isHidden = true
        }
        
        // 复制按钮
        let copyWidth = copyButton.intrinsicContentSize.width + buttonStyle.horizontalPadding * 2
        copyButton.frame = CGRect(
            x: bounds.width - padding.right - copyWidth,
            y: (headerHeight - buttonStyle.height) / 2,
            width: copyWidth,
            height: buttonStyle.height
        )
        
        // 代码区域
        let codeY = headerHeight
        let codeHeight = bounds.height - headerHeight
        scrollView.frame = CGRect(
            x: 0,
            y: codeY,
            width: bounds.width,
            height: codeHeight
        )
        
        // 计算代码实际大小
        let codeSize = calculateCodeSize()
        
        codeLabel.frame = CGRect(
            x: padding.left,
            y: padding.top,
            width: max(codeSize.width, scrollView.bounds.width - padding.left - padding.right),
            height: codeSize.height
        )
        
        scrollView.contentSize = CGSize(
            width: max(codeSize.width + padding.left + padding.right, scrollView.bounds.width),
            height: codeSize.height + padding.top + padding.bottom
        )
    }
    
    private func calculateCodeSize() -> CGSize {
        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        let text = codeLabel.text ?? ""
        let font = codeLabel.font ?? theme.code.font
        
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let boundingRect = (text as NSString).boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        
        // 添加少量余量避免截断
        let padding = blockStyle.contentPadding
        return CGSize(
            width: ceil(boundingRect.width) + padding,
            height: ceil(boundingRect.height) + padding
        )
    }
    
    // MARK: - Configuration
    
    /// 配置代码块视图（统一接口）
    /// - Parameters:
    ///   - content: CodeBlockContent 数据
    ///   - theme: 主题配置
    /// - Note: 高度由 ContainerView 通过 frame 设置，View 只负责布局子视图
    public func configure(content: Any, theme: MarkdownTheme) {
        guard let codeContent = content as? CodeBlockContent else { return }
        
        self.currentFragmentId = codeContent.fragmentId
        self.currentCode = codeContent.code
        self.currentLanguage = codeContent.language
        self.theme = theme
        
        // 应用样式
        applyTheme()
        
        // 语言标签
        languageLabel.text = codeContent.language.lowercased()
        languageBadge.isHidden = codeContent.language.isEmpty
        
        // 代码内容
        let trimmedCode = codeContent.code.trimmingCharacters(in: .whitespacesAndNewlines)
        codeLabel.text = trimmedCode
        
        // 复制按钮状态（根据 Content，无本地状态）
        updateCopyButtonAppearance(isCopied: codeContent.isCopied)
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    private func updateCopyButtonAppearance(isCopied: Bool) {
        if isCopied {
            copyButton.setTitle(buttonStyle.copiedTitle, for: .normal)
            copyButton.setImage(
                UIImage(systemName: buttonStyle.copiedIconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: buttonStyle.iconPointSize)),
                for: .normal
            )
            copyButton.tintColor = buttonStyle.copiedTextColor
            copyButton.setTitleColor(buttonStyle.copiedTextColor, for: .normal)
        } else {
            copyButton.setTitle(buttonStyle.copyTitle, for: .normal)
            copyButton.setImage(
                UIImage(systemName: buttonStyle.copyIconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: buttonStyle.iconPointSize)),
                for: .normal
            )
            copyButton.tintColor = buttonStyle.textColor
            copyButton.setTitleColor(buttonStyle.textColor, for: .normal)
        }
    }
    
    // MARK: - FragmentView (静态高度计算)

    public static func calculateHeight(
        content: CodeBlockContent,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        content.calculateEstimatedHeight(maxWidth: maxWidth, theme: theme)
    }

    /// 按显示进度计算预估高度
    /// - Note: displayedLength 对代码块表示已显示字符数；displayedLength >= codeText.count 时等价完整高度
    public static func estimatedHeight(
        codeText: String,
        displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        let codeStyle = theme.code
        let padding = codeStyle.block.padding
        let headerHeight = codeStyle.block.header.height

        let trimmed = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let totalChars = (trimmed as NSString).length
        let safeLen = totalChars > 0 ? min(max(0, displayedLength), totalChars) : 0

        let availableWidth = maxWidth - padding.left - padding.right
        let measuredText: String
        if safeLen <= 0 {
            measuredText = ""
        } else if safeLen >= totalChars {
            measuredText = trimmed
        } else {
            measuredText = (trimmed as NSString).substring(to: safeLen)
        }

        let textHeight: CGFloat
        if measuredText.isEmpty {
            textHeight = codeStyle.font.lineHeight
        } else {
            let textSize = (measuredText as NSString).boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: codeStyle.font],
                context: nil
            )
            textHeight = ceil(textSize.height)
        }

        var actualHeight = headerHeight + textHeight + padding.top + padding.bottom
        if let maxHeight = codeStyle.block.maxDisplayHeight {
            actualHeight = min(actualHeight, maxHeight)
        }
        return actualHeight
    }
    
    private func applyTheme() {
        // 容器样式
        containerView.backgroundColor = blockStyle.backgroundColor
        containerView.layer.cornerRadius = blockStyle.cornerRadius
        containerView.layer.borderWidth = blockStyle.borderWidth
        containerView.layer.borderColor = blockStyle.borderColor.cgColor
        
        // 代码标签样式
        codeLabel.font = theme.code.font
        codeLabel.textColor = theme.code.inlineColor
        
        // Badge 样式
        languageBadge.backgroundColor = badgeStyle.backgroundColor
        languageBadge.layer.cornerRadius = badgeStyle.cornerRadius
        languageLabel.font = badgeStyle.font
        languageLabel.textColor = badgeStyle.textColor
        
        // 复制按钮样式
        copyButton.titleLabel?.font = buttonStyle.font
        copyButton.tintColor = buttonStyle.textColor
        copyButton.setTitleColor(buttonStyle.textColor, for: .normal)
        copyButton.backgroundColor = buttonStyle.backgroundColor
        copyButton.layer.cornerRadius = buttonStyle.cornerRadius
        copyButton.contentEdgeInsets = buttonStyle.contentInsets
        copyButton.setTitle(buttonStyle.copyTitle, for: .normal)
        copyButton.setImage(
            UIImage(systemName: buttonStyle.copyIconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: buttonStyle.iconPointSize)),
            for: .normal
        )
    }
    
    // MARK: - Actions
    
    @objc private func copyCode() {
        UIPasteboard.general.string = currentCode
        
        // 动画反馈（短暂按下效果）
        let animationDuration = buttonStyle.pressedAnimationDuration
        let pressedScale = buttonStyle.pressedScale
        UIView.animate(withDuration: animationDuration) {
            self.copyButton.transform = CGAffineTransform(scaleX: pressedScale, y: pressedScale)
        } completion: { _ in
            UIView.animate(withDuration: animationDuration) {
                self.copyButton.transform = .identity
            }
        }
        
        // 上报事件，由 handleEvent 更新 StateStore 并触发 render
        onEvent?(CopyEvent(fragmentId: currentFragmentId, copiedText: currentCode))
    }
}

// MARK: - UIColor Extension

private extension UIColor {
    func darker(by percentage: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: max(b - percentage, 0), alpha: a)
        }
        return self
    }
}
