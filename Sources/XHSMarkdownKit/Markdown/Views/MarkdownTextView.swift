import UIKit

public final class MarkdownTextView: UIView, HeightEstimatable, StreamableContent {

    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.backgroundColor = .clear
        return tv
    }()

    private var fullAttributedString: NSAttributedString?
    private var indent: CGFloat = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(textView)
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    public func configure(attributedString: NSAttributedString, indent: CGFloat) {
        self.fullAttributedString = attributedString
        self.indent = indent
        textView.attributedText = attributedString
    }

    // MARK: - HeightEstimatable

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        guard let attrString = fullAttributedString else { return 0 }

        let displayedString: NSAttributedString
        if atDisplayedLength >= attrString.length {
            displayedString = attrString
        } else {
            displayedString = attrString.attributedSubstring(from: NSRange(location: 0, length: max(0, atDisplayedLength)))
        }

        let availableWidth = max(1, maxWidth - indent)
        let boundingRect = displayedString.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height)
    }

    // MARK: - StreamableContent

    public func reveal(upTo length: Int) {
        guard let attrString = fullAttributedString else { return }
        let clampedLength = max(0, min(length, attrString.length))
        if clampedLength >= attrString.length {
            textView.attributedText = attrString
        } else {
            textView.attributedText = attrString.attributedSubstring(from: NSRange(location: 0, length: clampedLength))
        }
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = CGRect(x: indent, y: 0, width: max(0, bounds.width - indent), height: bounds.height)
    }
}
