import UIKit

public protocol FragmentContaining: AnyObject {
    var differ: FragmentDiffing { get set }
    var animationDriver: AnimationDriver { get set }
    var viewPool: ViewPool { get }
    var containerView: UIView { get }
    var managedViews: [String: UIView] { get set }

    func update(_ fragments: [RenderFragment])
}
