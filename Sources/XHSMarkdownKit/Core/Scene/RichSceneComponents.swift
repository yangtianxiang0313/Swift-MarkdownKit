import UIKit

public struct CodeBlockSceneComponent: SceneComponent {
    public let code: String
    public let language: String?
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

    public func reveal(view: UIView, displayedUnits: Int) {
        guard let codeView = view as? CodeBlockSceneView else { return }
        codeView.reveal(upTo: displayedUnits)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? CodeBlockSceneComponent else { return false }
        return code == rhs.code
            && language == rhs.language
            && font == rhs.font
            && textColor == rhs.textColor
            && backgroundColor == rhs.backgroundColor
            && cornerRadius == rhs.cornerRadius
            && padding == rhs.padding
            && borderWidth == rhs.borderWidth
            && borderColor == rhs.borderColor
    }
}

public struct TableSceneComponent: SceneComponent {
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
    public var revealUnitCount: Int { 1 }

    public func makeView() -> UIView {
        TableSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let tableView = view as? TableSceneView else { return }
        tableView.configure(component: self, maxWidth: maxWidth)
    }

    public func reveal(view: UIView, displayedUnits: Int) {}

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
    public var revealUnitCount: Int { 1 }

    public func makeView() -> UIView {
        ImagePlaceholderSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let imageView = view as? ImagePlaceholderSceneView else { return }
        imageView.configure(component: self)
    }

    public func reveal(view: UIView, displayedUnits: Int) {}

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

public struct BlockQuoteTextSceneComponent: SceneComponent {
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

    public func reveal(view: UIView, displayedUnits: Int) {
        guard let quoteView = view as? BlockQuoteTextSceneView else { return }
        quoteView.reveal(upTo: displayedUnits)
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
    public var revealUnitCount: Int { 1 }

    public func makeView() -> UIView {
        BlockQuoteContainerSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let quoteView = view as? BlockQuoteContainerSceneView else { return }
        quoteView.configure(component: self)
    }

    public func reveal(view: UIView, displayedUnits: Int) {}

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? BlockQuoteContainerSceneComponent else { return false }
        return barColor == rhs.barColor
            && barWidth == rhs.barWidth
            && contentLeadingInset == rhs.contentLeadingInset
            && contentInsets == rhs.contentInsets
            && fillColor == rhs.fillColor
    }
}

private final class CodeBlockSceneView: UIView {
    private let headerView = UIView()
    private let languageLabel = UILabel()
    private let scrollView = UIScrollView()
    private let codeTextView = UITextView()

    private var fullCode: String = ""
    private var contentPadding: UIEdgeInsets = .zero
    private var configuredMaxWidth: CGFloat = 0
    private var codeFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    private var hasLanguageHeader: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        headerView.addSubview(languageLabel)
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
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: CodeBlockSceneComponent, maxWidth: CGFloat) {
        fullCode = component.code
        contentPadding = component.padding
        configuredMaxWidth = max(1, maxWidth)
        codeFont = component.font

        backgroundColor = component.backgroundColor
        layer.cornerRadius = component.cornerRadius
        layer.borderWidth = component.borderWidth
        layer.borderColor = component.borderColor.cgColor
        layer.masksToBounds = true

        if let language = component.language, !language.isEmpty {
            languageLabel.text = language.uppercased()
            languageLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            languageLabel.textColor = .secondaryLabel
            headerView.isHidden = false
            hasLanguageHeader = true
        } else {
            languageLabel.text = nil
            headerView.isHidden = true
            hasLanguageHeader = false
        }

        codeTextView.font = component.font
        codeTextView.textColor = component.textColor
        codeTextView.text = component.code

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func reveal(upTo displayedUnits: Int) {
        let clamped = max(0, min(displayedUnits, fullCode.count))
        let end = fullCode.index(fullCode.startIndex, offsetBy: clamped)
        codeTextView.text = String(fullCode[..<end])
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

        let horizontalPadding: CGFloat = max(0, contentPadding.left)
        let verticalPaddingTop: CGFloat = max(0, contentPadding.top)
        let verticalPaddingBottom: CGFloat = max(0, contentPadding.bottom)
        let trailingPadding: CGFloat = max(0, contentPadding.right)
        let headerHeight: CGFloat = headerView.isHidden ? 0 : 28

        headerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        languageLabel.frame = CGRect(
            x: horizontalPadding,
            y: 0,
            width: max(0, bounds.width - horizontalPadding - trailingPadding),
            height: headerHeight
        )

        scrollView.frame = CGRect(
            x: horizontalPadding,
            y: headerHeight + verticalPaddingTop,
            width: max(0, bounds.width - horizontalPadding - trailingPadding),
            height: max(0, bounds.height - headerHeight - verticalPaddingTop - verticalPaddingBottom)
        )

        let attr = NSAttributedString(
            string: codeTextView.text ?? "",
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
    }

    private func measuredSize(for width: CGFloat) -> CGSize {
        let targetWidth = max(1, width)
        let text = codeTextView.text ?? ""
        let attr = NSAttributedString(
            string: text,
            attributes: [.font: codeFont]
        )
        let textSize = attr.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        let headerHeight: CGFloat = hasLanguageHeader ? 28 : 0
        let height = headerHeight
            + max(ceil(textSize.height), codeFont.lineHeight)
            + max(0, contentPadding.top)
            + max(0, contentPadding.bottom)
        return CGSize(width: targetWidth, height: ceil(height))
    }
}

private final class BlockQuoteTextSceneView: UIView {
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

    func reveal(upTo displayedUnits: Int) {
        let text = sourceText.string
        let clamped = max(0, min(displayedUnits, text.count))
        if clamped <= 0 {
            label.attributedText = NSAttributedString(string: "")
            return
        }
        label.attributedText = sourceText.attributedSubstring(
            from: NSRange(location: 0, length: clamped)
        )
    }
}

private final class BlockQuoteContainerSceneView: UIView, SceneContainerView {
    private let barView = UIView()
    let contentStackView = UIStackView()

    private var contentLeadingConstraint: NSLayoutConstraint!
    private var contentTrailingConstraint: NSLayoutConstraint!
    private var contentTopConstraint: NSLayoutConstraint!
    private var contentBottomConstraint: NSLayoutConstraint!
    private var barLeadingConstraint: NSLayoutConstraint!
    private var barWidthConstraint: NSLayoutConstraint!
    private var barTopConstraint: NSLayoutConstraint!
    private var barBottomConstraint: NSLayoutConstraint!

    var sceneContentStackView: UIStackView { contentStackView }

    var sceneContentWidthReduction: CGFloat {
        contentLeadingConstraint.constant + max(0, -contentTrailingConstraint.constant)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        barView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 0
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill

        addSubview(barView)
        addSubview(contentStackView)

        barLeadingConstraint = barView.leadingAnchor.constraint(equalTo: leadingAnchor)
        barWidthConstraint = barView.widthAnchor.constraint(equalToConstant: 3)
        barTopConstraint = barView.topAnchor.constraint(equalTo: topAnchor)
        barBottomConstraint = barView.bottomAnchor.constraint(equalTo: bottomAnchor)

        contentLeadingConstraint = contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        contentTrailingConstraint = contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        contentTopConstraint = contentStackView.topAnchor.constraint(equalTo: topAnchor)
        contentBottomConstraint = contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor)

        NSLayoutConstraint.activate([
            barLeadingConstraint,
            barWidthConstraint,
            barTopConstraint,
            barBottomConstraint,
            contentLeadingConstraint,
            contentTrailingConstraint,
            contentTopConstraint,
            contentBottomConstraint
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: BlockQuoteContainerSceneComponent) {
        barView.backgroundColor = component.barColor
        backgroundColor = component.fillColor ?? .clear

        barLeadingConstraint.constant = component.contentInsets.left
        barTopConstraint.constant = component.contentInsets.top
        barBottomConstraint.constant = -component.contentInsets.bottom
        barWidthConstraint.constant = max(1, component.barWidth)

        let leading = max(component.contentInsets.left + component.barWidth + 1, component.contentLeadingInset)
        contentLeadingConstraint.constant = leading
        contentTrailingConstraint.constant = -component.contentInsets.right
        contentTopConstraint.constant = component.contentInsets.top
        contentBottomConstraint.constant = -component.contentInsets.bottom
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

private final class TableSceneView: UIView {
    private let scrollView = UIScrollView()
    private let contentView = TableGridContentView()

    private var component: TableSceneComponent?
    private var configuredMaxWidth: CGFloat = 0

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
        let layout = contentView.layout(component: component, availableWidth: availableWidth)
        contentView.frame = CGRect(x: 0, y: 0, width: layout.totalWidth, height: layout.totalHeight)
        scrollView.contentSize = CGSize(width: layout.totalWidth, height: layout.totalHeight)
        contentView.setNeedsDisplay()
    }

    private func measuredSize(for width: CGFloat) -> CGSize {
        guard let component else {
            return CGSize(width: max(1, width), height: UIView.noIntrinsicMetric)
        }
        let layout = contentView.layout(component: component, availableWidth: max(1, width))
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

    func layout(component: TableSceneComponent, availableWidth: CGFloat) -> Layout {
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

        var rowHeights: [CGFloat] = []
        rowHeights.reserveCapacity(component.rows.count + 1)

        let minRowHeight = minimumRowHeight(component: component)
        rowHeights.append(rowHeight(
            cells: component.headers,
            alignments: component.alignments,
            columnWidths: widths,
            component: component,
            minimum: minRowHeight
        ))
        for row in component.rows {
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

        let rowCount = component.rows.count + 1
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

        for (rowIndex, rowData) in component.rows.enumerated() {
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
