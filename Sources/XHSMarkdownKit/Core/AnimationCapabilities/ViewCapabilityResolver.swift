import UIKit

public struct ViewCapabilityResolver {
    public init() {}

    public func textRevealCapability(from view: UIView) -> TextRevealCapable? {
        view as? TextRevealCapable
    }

    public func overlayHostCapability(from view: UIView) -> OverlayHostCapable? {
        view as? OverlayHostCapable
    }

    public func heightAnimationCapability(from view: UIView) -> HeightAnimatableCapable? {
        view as? HeightAnimatableCapable
    }
}
