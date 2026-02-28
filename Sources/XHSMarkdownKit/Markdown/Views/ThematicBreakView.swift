import UIKit

public final class ThematicBreakView: UIView, HeightEstimatable {

    private let lineView = UIView()
    private var lineHeight: CGFloat = 1.0
    private var verticalPadding: CGFloat = 7.5

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(lineView)
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(color: UIColor, height: CGFloat, verticalPadding: CGFloat = 7.5) {
        lineView.backgroundColor = color
        lineHeight = height
        self.verticalPadding = verticalPadding
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        lineHeight + verticalPadding * 2
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        lineView.frame = CGRect(x: 0, y: verticalPadding, width: bounds.width, height: lineHeight)
    }
}
