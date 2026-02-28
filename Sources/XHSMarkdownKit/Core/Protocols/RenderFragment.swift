import Foundation

public protocol RenderFragment: AnyObject {
    var fragmentId: String { get }
    var nodeType: FragmentNodeType { get }
    var spacingAfter: CGFloat { get set }
}
