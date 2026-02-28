import UIKit

public protocol ViewTransition {
    func animateIn(view: UIView, completion: @escaping () -> Void)
    func animateOut(view: UIView, completion: @escaping () -> Void)
}
