import UIKit

public protocol HeightEstimatable {
    func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat
}
