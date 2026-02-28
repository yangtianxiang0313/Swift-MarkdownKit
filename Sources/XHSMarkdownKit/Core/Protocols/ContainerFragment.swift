import Foundation

public protocol ContainerFragment: FragmentViewFactory {
    var childFragments: [RenderFragment] { get }
}
