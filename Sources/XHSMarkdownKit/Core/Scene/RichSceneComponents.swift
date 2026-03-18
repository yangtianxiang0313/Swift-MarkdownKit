import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public struct CodeBlockSceneComponent: RevealAnimatableComponent {
    public let code: String
    public let language: String?
    public let copyStatus: String
    public let debugNodeID: String
    public let font: UIFont
    public let textColor: UIColor
    public let backgroundColor: UIColor
    public let cornerRadius: CGFloat
    public let padding: UIEdgeInsets
    public let borderWidth: CGFloat
    public let borderColor: UIColor

    public init(
        code: String,
        language: String?,
        copyStatus: String = "idle",
        debugNodeID: String = "",
        font: UIFont,
        textColor: UIColor,
        backgroundColor: UIColor,
        cornerRadius: CGFloat,
        padding: UIEdgeInsets,
        borderWidth: CGFloat,
        borderColor: UIColor
    ) {
        self.code = code
        self.language = language
        self.copyStatus = copyStatus
        self.debugNodeID = debugNodeID
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderWidth = borderWidth
        self.borderColor = borderColor
    }

    public var reuseIdentifier: String { "scene.codeBlock" }
    public var revealUnitCount: Int { max(1, code.count) }

    public func makeView() -> UIView {
        CodeBlockSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let codeView = view as? CodeBlockSceneView else { return }
        codeView.configure(component: self, maxWidth: maxWidth)
    }

    public func reveal(view: UIView, state: RevealState) {
        guard let revealView = view as? (UIView & RevealLayoutAnimatableView) else { return }
        revealView.applyRevealState(state)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? CodeBlockSceneComponent else { return false }
        return code == rhs.code
            && language == rhs.language
            && copyStatus == rhs.copyStatus
            && debugNodeID == rhs.debugNodeID
            && font == rhs.font
            && textColor == rhs.textColor
            && backgroundColor == rhs.backgroundColor
            && cornerRadius == rhs.cornerRadius
            && padding == rhs.padding
            && borderWidth == rhs.borderWidth
            && borderColor == rhs.borderColor
    }
}

public struct TableSceneComponent: RevealAnimatableComponent {
    public enum ColumnAlignment: Equatable {
        case left
        case center
        case right
    }

    public let headers: [NSAttributedString]
    public let rows: [[NSAttributedString]]
    public let alignments: [ColumnAlignment]
    public let headerBackgroundColor: UIColor
    public let borderColor: UIColor
    public let cornerRadius: CGFloat
    public let cellPadding: UIEdgeInsets

    public init(
        headers: [NSAttributedString],
        rows: [[NSAttributedString]],
        alignments: [ColumnAlignment],
        headerBackgroundColor: UIColor,
        borderColor: UIColor,
        cornerRadius: CGFloat,
        cellPadding: UIEdgeInsets
    ) {
        self.headers = headers
        self.rows = rows
        self.alignments = alignments
        self.headerBackgroundColor = headerBackgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.cellPadding = cellPadding
    }

    public var reuseIdentifier: String { "scene.table" }
    public var revealUnitCount: Int { max(1, rows.count + 1) }

    public func makeView() -> UIView {
        TableSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let tableView = view as? TableSceneView else { return }
        tableView.configure(component: self, maxWidth: maxWidth)
    }

    public func reveal(view: UIView, state: RevealState) {
        guard let revealView = view as? (UIView & RevealLayoutAnimatableView) else { return }
        revealView.applyRevealState(state)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? TableSceneComponent else { return false }
        return alignments == rhs.alignments
            && headerBackgroundColor == rhs.headerBackgroundColor
            && borderColor == rhs.borderColor
            && cornerRadius == rhs.cornerRadius
            && cellPadding == rhs.cellPadding
            && headers.elementsEqual(rhs.headers, by: { $0.isEqual($1) })
            && rowsEqual(lhs: rows, rhs: rhs.rows)
    }

    private func rowsEqual(lhs: [[NSAttributedString]], rhs: [[NSAttributedString]]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (lhsRow, rhsRow) in zip(lhs, rhs) {
            guard lhsRow.count == rhsRow.count else { return false }
            for (lhsCell, rhsCell) in zip(lhsRow, rhsRow) where !lhsCell.isEqual(rhsCell) {
                return false
            }
        }
        return true
    }
}

public struct ImagePlaceholderSceneComponent: SceneComponent {
    public let altText: String
    public let source: String?
    public let placeholderColor: UIColor
    public let cornerRadius: CGFloat
    public let placeholderHeight: CGFloat
    public let textFont: UIFont
    public let textColor: UIColor

    public init(
        altText: String,
        source: String?,
        placeholderColor: UIColor,
        cornerRadius: CGFloat,
        placeholderHeight: CGFloat,
        textFont: UIFont,
        textColor: UIColor
    ) {
        self.altText = altText
        self.source = source
        self.placeholderColor = placeholderColor
        self.cornerRadius = cornerRadius
        self.placeholderHeight = placeholderHeight
        self.textFont = textFont
        self.textColor = textColor
    }

    public var reuseIdentifier: String { "scene.imagePlaceholder" }

    public func makeView() -> UIView {
        ImagePlaceholderSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let imageView = view as? ImagePlaceholderSceneView else { return }
        imageView.configure(component: self)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? ImagePlaceholderSceneComponent else { return false }
        return altText == rhs.altText
            && source == rhs.source
            && placeholderColor == rhs.placeholderColor
            && cornerRadius == rhs.cornerRadius
            && placeholderHeight == rhs.placeholderHeight
            && textFont == rhs.textFont
            && textColor == rhs.textColor
    }
}

public struct BlockQuoteTextSceneComponent: RevealAnimatableComponent {
    public let attributedText: NSAttributedString
    public let numberOfLines: Int
    public let barColor: UIColor
    public let barWidth: CGFloat
    public let barSpacing: CGFloat
    public let contentInsets: UIEdgeInsets
    public let fillColor: UIColor?

    public init(
        attributedText: NSAttributedString,
        numberOfLines: Int = 0,
        barColor: UIColor,
        barWidth: CGFloat,
        barSpacing: CGFloat,
        contentInsets: UIEdgeInsets = .zero,
        fillColor: UIColor? = nil
    ) {
        self.attributedText = attributedText
        self.numberOfLines = numberOfLines
        self.barColor = barColor
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.contentInsets = contentInsets
        self.fillColor = fillColor
    }

    public var reuseIdentifier: String { "scene.blockQuoteText" }
    public var revealUnitCount: Int { attributedText.string.count }

    public func makeView() -> UIView {
        BlockQuoteTextSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let quoteView = view as? BlockQuoteTextSceneView else { return }
        quoteView.configure(component: self, maxWidth: maxWidth)
    }

    public func reveal(view: UIView, state: RevealState) {
        guard let revealView = view as? (UIView & RevealLayoutAnimatableView) else { return }
        revealView.applyRevealState(state)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? BlockQuoteTextSceneComponent else { return false }
        return attributedText.isEqual(to: rhs.attributedText)
            && numberOfLines == rhs.numberOfLines
            && barColor == rhs.barColor
            && barWidth == rhs.barWidth
            && barSpacing == rhs.barSpacing
            && contentInsets == rhs.contentInsets
            && fillColor == rhs.fillColor
    }
}

public struct BlockQuoteContainerSceneComponent: SceneComponent {
    public let barColor: UIColor
    public let barWidth: CGFloat
    public let contentLeadingInset: CGFloat
    public let contentInsets: UIEdgeInsets
    public let fillColor: UIColor?

    public init(
        barColor: UIColor,
        barWidth: CGFloat,
        contentLeadingInset: CGFloat,
        contentInsets: UIEdgeInsets = .zero,
        fillColor: UIColor? = nil
    ) {
        self.barColor = barColor
        self.barWidth = barWidth
        self.contentLeadingInset = contentLeadingInset
        self.contentInsets = contentInsets
        self.fillColor = fillColor
    }

    public var reuseIdentifier: String { "scene.blockQuoteContainer" }

    public func makeView() -> UIView {
        BlockQuoteContainerSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let quoteView = view as? BlockQuoteContainerSceneView else { return }
        quoteView.configure(component: self)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? BlockQuoteContainerSceneComponent else { return false }
        return barColor == rhs.barColor
            && barWidth == rhs.barWidth
            && contentLeadingInset == rhs.contentLeadingInset
            && contentInsets == rhs.contentInsets
            && fillColor == rhs.fillColor
    }
}

private final class CodeBlockSceneView: UIView, SceneInteractionEmitting, RevealLayoutAnimatableView {
    private struct ConfigureSignature: Equatable {
        let code: String
        let language: String?
        let copyStatus: String
        let maxWidth: CGFloat
        let font: UIFont
        let textColor: UIColor
        let backgroundColor: UIColor
        let cornerRadius: CGFloat
        let padding: UIEdgeInsets
        let borderWidth: CGFloat
        let borderColor: UIColor
    }

    private let headerView = UIView()
    private let languageLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let codeTextView = UITextView()

    private var fullCode: String = ""
    private var contentPadding: UIEdgeInsets = .zero
    private var configuredMaxWidth: CGFloat = 0
    private var codeFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    private var hasHeader: Bool = false
    private var copyStatus: String = "idle"
    private var visibleCharacters: Int = 0
    private var codeTextColor: UIColor = .label
    private var debugNodeID: String = "unknown"
    private var lastMeasuredHeight: CGFloat = -1
    private var lastMeasuredWidth: CGFloat = -1
    private var lastLoggedVisibleCharacters: Int = -1
    private var lastLoggedFrame: CGRect = .null
    private var lastLoggedContentSize: CGSize = .zero
    private var lastConfigureSignature: ConfigureSignature?
    var sceneInteractionHandler: ((SceneInteractionPayload) -> Bool)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        headerView.addSubview(languageLabel)
        headerView.addSubview(copyButton)
        addSubview(headerView)

        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)

        codeTextView.isEditable = false
        codeTextView.isSelectable = true
        codeTextView.isScrollEnabled = false
        codeTextView.backgroundColor = .clear
        codeTextView.textContainerInset = .zero
        codeTextView.textContainer.lineFragmentPadding = 0
        codeTextView.textContainer.lineBreakMode = .byClipping
        scrollView.addSubview(codeTextView)

        copyButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: CodeBlockSceneComponent, maxWidth: CGFloat) {
        let signature = ConfigureSignature(
            code: component.code,
            language: component.language,
            copyStatus: component.copyStatus,
            maxWidth: max(1, maxWidth),
            font: component.font,
            textColor: component.textColor,
            backgroundColor: component.backgroundColor,
            cornerRadius: component.cornerRadius,
            padding: component.padding,
            borderWidth: component.borderWidth,
            borderColor: component.borderColor
        )
        debugNodeID = component.debugNodeID.isEmpty ? "unknown" : component.debugNodeID

        guard signature != lastConfigureSignature else {
            return
        }
        lastConfigureSignature = signature

        fullCode = signature.code
        copyStatus = signature.copyStatus
        contentPadding = signature.padding
        configuredMaxWidth = signature.maxWidth
        codeFont = signature.font
        codeTextColor = signature.textColor
        visibleCharacters = min(visibleCharacters, fullCode.count)

        backgroundColor = signature.backgroundColor
        layer.cornerRadius = signature.cornerRadius
        layer.borderWidth = signature.borderWidth
        layer.borderColor = signature.borderColor.cgColor
        layer.masksToBounds = true

        if let language = signature.language, !language.isEmpty {
            languageLabel.text = language.uppercased()
            languageLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            languageLabel.textColor = .secondaryLabel
        } else {
            languageLabel.text = nil
        }
        hasHeader = true
        headerView.isHidden = !hasHeader

        copyButton.setTitle(copyButtonTitle(for: copyStatus), for: .normal)

        codeTextView.font = signature.font
        renderVisibleCode(upTo: visibleCharacters)

        SceneDebugLogger.log(
            "CodeBlock configure node=\(debugNodeID) width=\(configuredMaxWidth) codeLen=\(fullCode.count) copyStatus=\(copyStatus)",
            level: .verbose
        )

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func applyRevealState(_ state: RevealState) {
        let displayedUnits = state.displayedUnits
        let clamped = max(0, min(displayedUnits, fullCode.count))
        guard clamped != visibleCharacters else { return }
        visibleCharacters = clamped
        renderVisibleCode(upTo: clamped)
        invalidateRevealLayout()
        if shouldLogReveal(for: clamped) {
            SceneDebugLogger.log(
                "CodeBlock reveal node=\(debugNodeID) visible=\(clamped)/\(fullCode.count)",
                level: .verbose
            )
            lastLoggedVisibleCharacters = clamped
        }
    }

    override var intrinsicContentSize: CGSize {
        measuredSize(for: configuredMaxWidth > 0 ? configuredMaxWidth : bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        measuredSize(for: size.width > 0 ? size.width : configuredMaxWidth)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let horizontalPadding: CGFloat = max(0, contentPadding.left)
        let verticalPaddingTop: CGFloat = max(0, contentPadding.top)
        let verticalPaddingBottom: CGFloat = max(0, contentPadding.bottom)
        let trailingPadding: CGFloat = max(0, contentPadding.right)
        let headerHeight: CGFloat = hasHeader ? 28 : 0

        headerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        let buttonWidth = copyButtonWidth()
        copyButton.frame = CGRect(
            x: max(0, bounds.width - trailingPadding - buttonWidth),
            y: 0,
            width: buttonWidth,
            height: headerHeight
        )
        languageLabel.frame = CGRect(
            x: horizontalPadding,
            y: 0,
            width: max(0, copyButton.frame.minX - horizontalPadding - 8),
            height: headerHeight
        )

        scrollView.frame = CGRect(
            x: horizontalPadding,
            y: headerHeight + verticalPaddingTop,
            width: max(0, bounds.width - horizontalPadding - trailingPadding),
            height: max(0, bounds.height - headerHeight - verticalPaddingTop - verticalPaddingBottom)
        )

        let layoutText = visibleCodeText()
        let textForLayout = layoutText.isEmpty ? " " : layoutText
        let attr = NSAttributedString(
            string: textForLayout,
            attributes: [.font: codeTextView.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)]
        )
        let codeSize = attr.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        let contentWidth = max(scrollView.bounds.width, ceil(codeSize.width))
        let contentHeight = max(scrollView.bounds.height, ceil(codeSize.height))
        codeTextView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)

        if frame.integral != lastLoggedFrame || scrollView.contentSize != lastLoggedContentSize {
            SceneDebugLogger.log(
                "CodeBlock layout node=\(debugNodeID) frame=\(frame.integral) scroll=\(scrollView.frame.integral) contentSize=\(scrollView.contentSize)",
                level: .verbose
            )
            lastLoggedFrame = frame.integral
            lastLoggedContentSize = scrollView.contentSize
        }
    }

    private func measuredSize(for width: CGFloat) -> CGSize {
        let targetWidth = max(1, width)
        let visibleText = visibleCodeText()
        let text = visibleText.isEmpty ? " " : visibleText
        let attr = NSAttributedString(
            string: text,
            attributes: [.font: codeFont]
        )
        let textSize = attr.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        let headerHeight: CGFloat = hasHeader ? 28 : 0
        let height = headerHeight
            + max(ceil(textSize.height), codeFont.lineHeight)
            + max(0, contentPadding.top)
            + max(0, contentPadding.bottom)
        let resolved = CGSize(width: targetWidth, height: ceil(height))
        if abs(lastMeasuredHeight - resolved.height) > 0.5 || abs(lastMeasuredWidth - targetWidth) > 0.5 {
            SceneDebugLogger.log(
                "CodeBlock measured node=\(debugNodeID) width=\(targetWidth) measuredHeight=\(resolved.height) visible=\(visibleCharacters)/\(fullCode.count)",
                level: .verbose
            )
            lastMeasuredHeight = resolved.height
            lastMeasuredWidth = targetWidth
        }
        return resolved
    }

    private func copyButtonTitle(for status: String) -> String {
        status == "copied" ? "Copied" : "Copy"
    }

    private func copyButtonWidth() -> CGFloat {
        let title = copyButton.title(for: .normal) ?? "Copy"
        let size = (title as NSString).size(withAttributes: [
            .font: copyButton.titleLabel?.font ?? UIFont.systemFont(ofSize: 12, weight: .semibold)
        ])
        return max(52, ceil(size.width) + 16)
    }

    @objc
    private func copyButtonTapped() {
        let payload = SceneInteractionPayload(
            action: "copyTap",
            payload: [
                "slot": .string("copyStatus"),
                "code": .string(fullCode)
            ]
        )
        let shouldApplyDefault = sceneInteractionHandler?(payload) ?? true
        if shouldApplyDefault {
            UIPasteboard.general.string = fullCode
        }
    }

    private func renderVisibleCode(upTo visibleCount: Int) {
        let clamped = max(0, min(visibleCount, fullCode.count))
        let visiblePrefix = String(fullCode.prefix(clamped))
        let rendered = NSAttributedString(
            string: visiblePrefix,
            attributes: [
                .font: codeFont,
                .foregroundColor: codeTextColor
            ]
        )
        codeTextView.attributedText = rendered
    }

    private func visibleCodeText() -> String {
        String(fullCode.prefix(max(0, min(visibleCharacters, fullCode.count))))
    }

    private func shouldLogReveal(for visibleCount: Int) -> Bool {
        guard SceneDebugLogger.isEnabled else { return false }
        if visibleCount == 0 || visibleCount == fullCode.count {
            return true
        }
        if lastLoggedVisibleCharacters < 0 {
            return true
        }
        return abs(visibleCount - lastLoggedVisibleCharacters) >= 24
    }
}

private final class BlockQuoteTextSceneView: UIView, RevealLayoutAnimatableView {
    private let barView = UIView()
    private let label = UILabel()

    private var sourceText = NSAttributedString(string: "")

    private var barLeadingConstraint: NSLayoutConstraint!
    private var barTopConstraint: NSLayoutConstraint!
    private var barBottomConstraint: NSLayoutConstraint!
    private var barWidthConstraint: NSLayoutConstraint!
    private var labelLeadingConstraint: NSLayoutConstraint!
    private var labelTrailingConstraint: NSLayoutConstraint!
    private var labelTopConstraint: NSLayoutConstraint!
    private var labelBottomConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)

        barView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        addSubview(barView)
        addSubview(label)

        barLeadingConstraint = barView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0)
        barTopConstraint = barView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        barBottomConstraint = barView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
        barWidthConstraint = barView.widthAnchor.constraint(equalToConstant: 3)

        labelLeadingConstraint = label.leadingAnchor.constraint(equalTo: barView.trailingAnchor, constant: 8)
        labelTrailingConstraint = label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0)
        labelTopConstraint = label.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        labelBottomConstraint = label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)

        NSLayoutConstraint.activate([
            barLeadingConstraint,
            barTopConstraint,
            barBottomConstraint,
            barWidthConstraint,
            labelLeadingConstraint,
            labelTrailingConstraint,
            labelTopConstraint,
            labelBottomConstraint
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: BlockQuoteTextSceneComponent, maxWidth: CGFloat) {
        sourceText = component.attributedText
        label.attributedText = component.attributedText
        label.numberOfLines = component.numberOfLines

        barView.backgroundColor = component.barColor
        backgroundColor = component.fillColor ?? .clear

        barLeadingConstraint.constant = component.contentInsets.left
        barTopConstraint.constant = component.contentInsets.top
        barBottomConstraint.constant = -component.contentInsets.bottom
        barWidthConstraint.constant = max(1, component.barWidth)

        labelLeadingConstraint.constant = max(0, component.barSpacing)
        labelTrailingConstraint.constant = -component.contentInsets.right
        labelTopConstraint.constant = component.contentInsets.top
        labelBottomConstraint.constant = -component.contentInsets.bottom

        let textMaxWidth = max(
            0,
            maxWidth
                - component.contentInsets.left
                - component.contentInsets.right
                - max(1, component.barWidth)
                - max(0, component.barSpacing)
        )
        label.preferredMaxLayoutWidth = textMaxWidth
    }

    func applyRevealState(_ state: RevealState) {
        let displayedUnits = state.displayedUnits
        let text = sourceText.string
        let clamped = max(0, min(displayedUnits, text.count))
        if clamped <= 0 {
            label.attributedText = NSAttributedString(string: "")
            invalidateRevealLayout()
            return
        }
        label.attributedText = sourceText.attributedSubstring(
            from: NSRange(location: 0, length: clamped)
        )
        invalidateRevealLayout()
    }
}

private final class BlockQuoteContainerSceneView: UIView, SceneContainerView {
    private let barView = UIView()
    let contentContainerView = UIView()

    private var resolvedContentInsets: UIEdgeInsets = .zero
    private var resolvedBarInsets: UIEdgeInsets = .zero
    private var resolvedBarWidth: CGFloat = 3

    var sceneContentContainerView: UIView { contentContainerView }
    var sceneContentInsets: UIEdgeInsets { resolvedContentInsets }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(barView)
        addSubview(contentContainerView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: BlockQuoteContainerSceneComponent) {
        barView.backgroundColor = component.barColor
        backgroundColor = component.fillColor ?? .clear

        resolvedBarInsets = component.contentInsets
        resolvedBarWidth = max(1, component.barWidth)

        let leading = max(component.contentInsets.left + component.barWidth + 1, component.contentLeadingInset)
        resolvedContentInsets = UIEdgeInsets(
            top: component.contentInsets.top,
            left: leading,
            bottom: component.contentInsets.bottom,
            right: component.contentInsets.right
        )
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        barView.frame = CGRect(
            x: resolvedBarInsets.left,
            y: resolvedBarInsets.top,
            width: resolvedBarWidth,
            height: max(0, bounds.height - resolvedBarInsets.top - resolvedBarInsets.bottom)
        )

        contentContainerView.frame = CGRect(
            x: resolvedContentInsets.left,
            y: resolvedContentInsets.top,
            width: max(0, bounds.width - resolvedContentInsets.left - resolvedContentInsets.right),
            height: max(0, bounds.height - resolvedContentInsets.top - resolvedContentInsets.bottom)
        )
    }
}

private final class ImagePlaceholderSceneView: UIView {
    private let placeholderView = UIView()
    private let glyphView = UIImageView(image: UIImage(systemName: "photo"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var placeholderHeight: CGFloat = 200

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(placeholderView)
        placeholderView.addSubview(glyphView)
        placeholderView.addSubview(titleLabel)
        placeholderView.addSubview(subtitleLabel)

        glyphView.contentMode = .scaleAspectFit
        glyphView.tintColor = .secondaryLabel

        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        subtitleLabel.numberOfLines = 1
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.font = .systemFont(ofSize: 12)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: ImagePlaceholderSceneComponent) {
        placeholderHeight = component.placeholderHeight
        placeholderView.backgroundColor = component.placeholderColor
        placeholderView.layer.cornerRadius = component.cornerRadius
        placeholderView.clipsToBounds = true

        titleLabel.font = component.textFont
        titleLabel.textColor = component.textColor
        titleLabel.text = component.altText.isEmpty ? "Image" : component.altText

        subtitleLabel.text = component.source
        subtitleLabel.isHidden = (component.source == nil)

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: placeholderHeight)

        glyphView.frame = CGRect(
            x: (placeholderView.bounds.width - 32) / 2,
            y: max(16, placeholderView.bounds.height * 0.28 - 16),
            width: 32,
            height: 32
        )

        let textWidth = max(0, placeholderView.bounds.width - 24)
        titleLabel.frame = CGRect(
            x: 12,
            y: glyphView.frame.maxY + 8,
            width: textWidth,
            height: 40
        )
        subtitleLabel.frame = CGRect(
            x: 12,
            y: titleLabel.frame.maxY + 4,
            width: textWidth,
            height: 16
        )
    }
}

private final class TableSceneView: UIView, RevealLayoutAnimatableView {
    private let scrollView = UIScrollView()
    private let contentView = TableGridContentView()

    private var component: TableSceneComponent?
    private var configuredMaxWidth: CGFloat = 0
    private var visibleRowCount: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = true

        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true

        addSubview(scrollView)
        scrollView.addSubview(contentView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: TableSceneComponent, maxWidth: CGFloat) {
        self.component = component
        configuredMaxWidth = max(1, maxWidth)
        visibleRowCount = component.rows.count + 1

        layer.cornerRadius = component.cornerRadius
        layer.borderWidth = 0.5
        layer.borderColor = component.borderColor.cgColor

        contentView.component = component
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        measuredSize(for: configuredMaxWidth > 0 ? configuredMaxWidth : bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        measuredSize(for: size.width > 0 ? size.width : configuredMaxWidth)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        guard let component else { return }
        let availableWidth = max(1, bounds.width > 0 ? bounds.width : configuredMaxWidth)
        let layout = contentView.layout(
            component: component,
            availableWidth: availableWidth,
            visibleRowCount: visibleRowCount
        )
        contentView.frame = CGRect(x: 0, y: 0, width: layout.totalWidth, height: layout.totalHeight)
        scrollView.contentSize = CGSize(width: layout.totalWidth, height: layout.totalHeight)
        contentView.setNeedsDisplay()
    }

    func applyRevealState(_ state: RevealState) {
        setVisibleRowCount(state.displayedUnits)
    }

    private func setVisibleRowCount(_ count: Int) {
        guard let component else { return }
        let clamped = min(component.rows.count + 1, max(0, count))
        guard visibleRowCount != clamped else { return }
        visibleRowCount = clamped
        invalidateRevealLayout()
        contentView.setNeedsDisplay()
    }

    private func measuredSize(for width: CGFloat) -> CGSize {
        guard let component else {
            return CGSize(width: max(1, width), height: UIView.noIntrinsicMetric)
        }
        let layout = contentView.layout(
            component: component,
            availableWidth: max(1, width),
            visibleRowCount: visibleRowCount
        )
        return CGSize(width: max(1, width), height: layout.totalHeight)
    }
}

private final class TableGridContentView: UIView {
    struct Layout {
        let columnWidths: [CGFloat]
        let rowHeights: [CGFloat]
        let totalWidth: CGFloat
        let totalHeight: CGFloat

        static let empty = Layout(columnWidths: [], rowHeights: [], totalWidth: 0, totalHeight: 0)
    }

    var component: TableSceneComponent?
    private var currentLayout: Layout = .empty

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func layout(
        component: TableSceneComponent,
        availableWidth: CGFloat,
        visibleRowCount: Int?
    ) -> Layout {
        let colCount = max(
            1,
            component.headers.count,
            component.rows.map(\.count).max() ?? 0
        )
        let padding = component.cellPadding.left + component.cellPadding.right
        let minColumnWidth: CGFloat = 64
        var widths = [CGFloat](repeating: minColumnWidth, count: colCount)

        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let measureOptions: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

        for index in 0..<colCount {
            let header = index < component.headers.count ? component.headers[index] : NSAttributedString(string: "")
            let headerSize = header.boundingRect(with: maxSize, options: measureOptions, context: nil).size
            widths[index] = max(widths[index], ceil(headerSize.width) + padding)
        }

        for row in component.rows {
            for index in 0..<colCount {
                let cell = index < row.count ? row[index] : NSAttributedString(string: "")
                let size = cell.boundingRect(with: maxSize, options: measureOptions, context: nil).size
                widths[index] = max(widths[index], ceil(size.width) + padding)
            }
        }

        let clampedAvailableWidth = max(1, availableWidth)
        let minTotalWidth = CGFloat(colCount) * minColumnWidth
        let naturalTotalWidth = widths.reduce(0, +)
        if naturalTotalWidth < clampedAvailableWidth {
            let extra = (clampedAvailableWidth - naturalTotalWidth) / CGFloat(colCount)
            widths = widths.map { $0 + extra }
        } else if naturalTotalWidth > clampedAvailableWidth, clampedAvailableWidth > minTotalWidth {
            let shrinkableWidth = naturalTotalWidth - minTotalWidth
            if shrinkableWidth > 0 {
                let targetShrinkableWidth = clampedAvailableWidth - minTotalWidth
                let scale = max(0, min(1, targetShrinkableWidth / shrinkableWidth))
                widths = widths.map { minColumnWidth + (($0 - minColumnWidth) * scale) }
            }
        }

        let resolvedVisibleRows = min(component.rows.count + 1, max(0, visibleRowCount ?? (component.rows.count + 1)))
        let visibleDataRowCount = max(0, resolvedVisibleRows - 1)
        let visibleRows = Array(component.rows.prefix(visibleDataRowCount))

        var rowHeights: [CGFloat] = []
        rowHeights.reserveCapacity(visibleRows.count + 1)

        let minRowHeight = minimumRowHeight(component: component)
        if resolvedVisibleRows > 0 {
            rowHeights.append(rowHeight(
                cells: component.headers,
                alignments: component.alignments,
                columnWidths: widths,
                component: component,
                minimum: minRowHeight
            ))
        }
        for row in visibleRows {
            rowHeights.append(rowHeight(
                cells: row,
                alignments: component.alignments,
                columnWidths: widths,
                component: component,
                minimum: minRowHeight
            ))
        }

        let totalWidth = max(clampedAvailableWidth, widths.reduce(0, +))
        let totalHeight = max(1, ceil(rowHeights.reduce(0, +) + 1))
        let resolved = Layout(
            columnWidths: widths,
            rowHeights: rowHeights,
            totalWidth: totalWidth,
            totalHeight: totalHeight
        )
        currentLayout = resolved
        return resolved
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let component else { return }
        guard !currentLayout.columnWidths.isEmpty, !currentLayout.rowHeights.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let rowCount = currentLayout.rowHeights.count
        let rowOrigins = cumulativeOffsets(for: currentLayout.rowHeights)
        guard rowOrigins.count == currentLayout.rowHeights.count else { return }

        let headerHeight = currentLayout.rowHeights[0]

        context.setFillColor(component.headerBackgroundColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight))

        drawRow(
            cells: component.headers,
            alignments: component.alignments,
            y: 0,
            rowHeight: headerHeight,
            component: component
        )

        let visibleDataRows = Array(component.rows.prefix(max(0, rowCount - 1)))
        for (rowIndex, rowData) in visibleDataRows.enumerated() {
            let visualRowIndex = rowIndex + 1
            let y = rowOrigins[visualRowIndex]
            let rowHeight = currentLayout.rowHeights[visualRowIndex]
            if rowIndex % 2 == 1 {
                context.setFillColor(component.headerBackgroundColor.withAlphaComponent(0.26).cgColor)
                context.fill(CGRect(x: 0, y: y, width: bounds.width, height: rowHeight))
            }
            drawRow(
                cells: rowData,
                alignments: component.alignments,
                y: y,
                rowHeight: rowHeight,
                component: component
            )
        }

        context.setStrokeColor(component.borderColor.cgColor)
        context.setLineWidth(0.5)

        for row in 0...rowCount {
            let y: CGFloat
            if row == rowCount {
                y = currentLayout.rowHeights.reduce(0, +)
            } else {
                y = rowOrigins[row]
            }
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
        }

        var x: CGFloat = 0
        for width in currentLayout.columnWidths {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: currentLayout.rowHeights.reduce(0, +)))
            x += width
        }
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: currentLayout.rowHeights.reduce(0, +)))
        context.strokePath()
    }

    private func drawRow(
        cells: [NSAttributedString],
        alignments: [TableSceneComponent.ColumnAlignment],
        y: CGFloat,
        rowHeight: CGFloat,
        component: TableSceneComponent
    ) {
        var x: CGFloat = 0
        let padding = component.cellPadding
        for (col, width) in currentLayout.columnWidths.enumerated() {
            let cell = col < cells.count ? cells[col] : NSAttributedString(string: "")
            let availableWidth = max(0, width - padding.left - padding.right)

            let alignment = col < alignments.count ? alignments[col] : .left
            let styledCell = applying(alignment: alignment, to: cell)
            let drawRect = CGRect(
                x: x + padding.left,
                y: y + padding.top,
                width: availableWidth,
                height: max(0, rowHeight - padding.top - padding.bottom)
            )
            styledCell.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            x += width
        }
    }

    private func minimumRowHeight(component: TableSceneComponent) -> CGFloat {
        let headerLine = component.headers.first?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let bodyLine = component.rows.first?.first?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let fontHeight = max(headerLine?.lineHeight ?? 17, bodyLine?.lineHeight ?? 17)
        return max(30, ceil(fontHeight + component.cellPadding.top + component.cellPadding.bottom))
    }

    private func rowHeight(
        cells: [NSAttributedString],
        alignments: [TableSceneComponent.ColumnAlignment],
        columnWidths: [CGFloat],
        component: TableSceneComponent,
        minimum: CGFloat
    ) -> CGFloat {
        let padding = component.cellPadding
        var maxHeight: CGFloat = 0
        for (index, columnWidth) in columnWidths.enumerated() {
            let cell = index < cells.count ? cells[index] : NSAttributedString(string: "")
            let alignment = index < alignments.count ? alignments[index] : .left
            let attributed = applying(alignment: alignment, to: cell)
            let availableWidth = max(0, columnWidth - padding.left - padding.right)
            let measured = attributed.boundingRect(
                with: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
            maxHeight = max(maxHeight, ceil(measured) + padding.top + padding.bottom)
        }
        return max(minimum, maxHeight)
    }

    private func cumulativeOffsets(for values: [CGFloat]) -> [CGFloat] {
        var offsets: [CGFloat] = []
        offsets.reserveCapacity(values.count)
        var current: CGFloat = 0
        for value in values {
            offsets.append(current)
            current += value
        }
        return offsets
    }

    private func applying(
        alignment: TableSceneComponent.ColumnAlignment,
        to attributed: NSAttributedString
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return mutable }

        let paragraphStyle = (mutable.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()

        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        }
        paragraphStyle.lineBreakMode = .byWordWrapping
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        return mutable
    }
}
