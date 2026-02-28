import Foundation

public protocol TransitionPreferring: RenderFragment {
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}
