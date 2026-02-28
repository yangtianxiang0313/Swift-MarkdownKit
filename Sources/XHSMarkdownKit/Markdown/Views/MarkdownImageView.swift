import UIKit

public final class MarkdownImageView: UIView, HeightEstimatable {

    private let imageView = UIImageView()
    private var placeholderHeight: CGFloat = 200
    private var maxImageWidth: CGFloat = 300

    public override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(source: String?, maxWidth: CGFloat, theme: MarkdownTheme.ImageStyle) {
        imageView.layer.cornerRadius = theme.cornerRadius
        placeholderHeight = theme.placeholderHeight
        maxImageWidth = min(maxWidth, theme.maxWidth)
        imageView.backgroundColor = theme.placeholderColor
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        if let image = imageView.image {
            let ratio = image.size.height / max(1, image.size.width)
            let displayWidth = min(maxWidth, maxImageWidth)
            return displayWidth * ratio
        }
        return placeholderHeight
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}
