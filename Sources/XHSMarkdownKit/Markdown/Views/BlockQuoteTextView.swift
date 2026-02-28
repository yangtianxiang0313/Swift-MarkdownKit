import UIKit

public final class BlockQuoteTextView: UIView, HeightEstimatable, StreamableContent {

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

    private var barViews: [UIView] = []
    private var fullAttributedString: NSAttributedString?
    private var depth: Int = 1
    private var barColor: UIColor = .separator
    private var barWidth: CGFloat = 3.0
    private var barLeftMargin: CGFloat = 8.0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(textView)
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(attributedString: NSAttributedString, depth: Int, theme: MarkdownTheme.BlockQuoteStyle) {
        self.fullAttributedString = attributedString
        self.depth = depth
        self.barColor = theme.barColor
        self.barWidth = theme.barWidth
        self.barLeftMargin = theme.barLeftMargin
        textView.attributedText = attributedString
        setupBars()
    }

    private func setupBars() {
        barViews.forEach { $0.removeFromSuperview() }
        barViews.removeAll()
        for _ in 0..<depth {
            let bar = UIView()
            bar.backgroundColor = barColor
            addSubview(bar)
            barViews.append(bar)
        }
    }

    private var textLeftOffset: CGFloat {
        CGFloat(depth) * (barWidth + barLeftMargin)
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        guard let attrString = fullAttributedString else { return 0 }
        let displayedString: NSAttributedString
        if atDisplayedLength >= attrString.length {
            displayedString = attrString
        } else {
            displayedString = attrString.attributedSubstring(from: NSRange(location: 0, length: max(0, atDisplayedLength)))
        }
        let width = max(1, maxWidth - textLeftOffset)
        let rect = displayedString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    public func reveal(upTo length: Int) {
        guard let attrString = fullAttributedString else { return }
        let clamped = max(0, min(length, attrString.length))
        textView.attributedText = attrString.attributedSubstring(from: NSRange(location: 0, length: clamped))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        for (i, bar) in barViews.enumerated() {
            let x = CGFloat(i) * (barWidth + barLeftMargin)
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: bounds.height)
        }
        textView.frame = CGRect(x: textLeftOffset, y: 0, width: max(0, bounds.width - textLeftOffset), height: bounds.height)
    }
}
