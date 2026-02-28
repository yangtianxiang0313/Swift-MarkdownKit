import UIKit

public struct FadeTransition: ViewTransition {
    public let duration: TimeInterval

    public init(duration: TimeInterval = 0.15) {
        self.duration = duration
    }

    public func animateIn(view: UIView, completion: @escaping () -> Void) {
        view.alpha = 0
        UIView.animate(withDuration: duration, animations: {
            view.alpha = 1
        }, completion: { _ in completion() })
    }

    public func animateOut(view: UIView, completion: @escaping () -> Void) {
        UIView.animate(withDuration: duration, animations: {
            view.alpha = 0
        }, completion: { _ in completion() })
    }
}
