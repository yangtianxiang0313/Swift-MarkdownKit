import UIKit

public final class CodeBlockView: UIView, HeightEstimatable, StreamableContent {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        return sv
    }()

    private let codeTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byClipping
        tv.backgroundColor = .clear
        return tv
    }()

    private let headerView = UIView()
    private let languageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private var fullCode: String = ""
    private var codeFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    private var codeStyle: MarkdownTheme.CodeBlockStyle = .default
    private var headerHeight: CGFloat { languageLabel.text?.isEmpty == false ? 32 : 0 }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(headerView)
        headerView.addSubview(languageLabel)
        addSubview(scrollView)
        scrollView.addSubview(codeTextView)
        layer.masksToBounds = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    public func configure(code: String, language: String?, theme: MarkdownTheme.CodeStyle) {
        self.fullCode = code
        self.codeStyle = theme.block
        self.codeFont = theme.font
        backgroundColor = theme.block.backgroundColor
        layer.cornerRadius = theme.block.cornerRadius
        layer.borderWidth = theme.block.borderWidth
        layer.borderColor = theme.block.borderColor.cgColor

        if let lang = language, !lang.isEmpty {
            languageLabel.text = lang.uppercased()
            headerView.isHidden = false
            headerView.backgroundColor = theme.block.backgroundColor
        } else {
            languageLabel.text = nil
            headerView.isHidden = true
        }

        codeTextView.font = codeFont
        codeTextView.textColor = .label
        codeTextView.text = code
        setNeedsLayout()
    }

    // MARK: - HeightEstimatable

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        let padding = codeStyle.padding
        let displayedCode: String
        if atDisplayedLength >= fullCode.count {
            displayedCode = fullCode
        } else {
            let index = fullCode.index(fullCode.startIndex, offsetBy: max(0, min(atDisplayedLength, fullCode.count)))
            displayedCode = String(fullCode[..<index])
        }

        let attrString = NSAttributedString(string: displayedCode, attributes: [.font: codeFont])
        let boundingRect = attrString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height) + padding.top + padding.bottom + headerHeight
    }

    // MARK: - StreamableContent

    public func reveal(upTo length: Int) {
        let clamped = max(0, min(length, fullCode.count))
        let index = fullCode.index(fullCode.startIndex, offsetBy: clamped)
        codeTextView.text = String(fullCode[..<index])
        updateCodeContentSize()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        let padding = codeStyle.padding
        let hh = headerHeight

        headerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: hh)
        languageLabel.frame = CGRect(x: padding.left, y: 0, width: bounds.width - padding.left - padding.right, height: hh)

        scrollView.frame = CGRect(
            x: padding.left, y: hh + padding.top,
            width: max(0, bounds.width - padding.left - padding.right),
            height: max(0, bounds.height - hh - padding.top - padding.bottom)
        )
        updateCodeContentSize()
    }

    private func updateCodeContentSize() {
        let attrString = NSAttributedString(string: codeTextView.text ?? "", attributes: [.font: codeFont])
        let size = attrString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        let contentWidth = max(scrollView.bounds.width, ceil(size.width))
        let contentHeight = max(scrollView.bounds.height, ceil(size.height))
        codeTextView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
    }
}
