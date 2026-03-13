import Foundation

public protocol RenderFragment: AnyObject {
    var fragmentId: String { get }
    var nodeType: FragmentNodeType { get }
    var spacingAfter: CGFloat { get set }
    func isContentEqual(to other: any RenderFragment) -> Bool
}

public extension RenderFragment {
    func isContentEqual(to other: any RenderFragment) -> Bool {
        guard fragmentId == other.fragmentId else { return false }
        guard nodeType == other.nodeType else { return false }
        guard spacingAfter == other.spacingAfter else { return false }

        if let lhsFactory = self as? FragmentViewFactory,
           let rhsFactory = other as? FragmentViewFactory {
            return lhsFactory.reuseIdentifier == rhsFactory.reuseIdentifier
        }
        return true
    }
}
