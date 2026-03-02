import UIKit

public final class MarkdownImageView: UIView, HeightEstimatable {

    private let imageView = UIImageView()
    private var config: ImageConfiguration?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(_ config: ImageConfiguration) {
        self.config = config
        imageView.layer.cornerRadius = config.cornerRadius
        imageView.backgroundColor = config.placeholderColor
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        guard let config = config else { return 200 }
        
        if let image = imageView.image {
            let ratio = image.size.height / max(1, image.size.width)
            let displayWidth = min(maxWidth, config.maxImageWidth)
            return displayWidth * ratio
        }
        return config.placeholderHeight
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}
