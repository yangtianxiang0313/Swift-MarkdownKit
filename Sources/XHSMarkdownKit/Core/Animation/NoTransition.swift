import UIKit

public struct NoTransition: ViewTransition {
    public init() {}

    public func animateIn(view: UIView, completion: @escaping () -> Void) {
        completion()
    }

    public func animateOut(view: UIView, completion: @escaping () -> Void) {
        completion()
    }
}
