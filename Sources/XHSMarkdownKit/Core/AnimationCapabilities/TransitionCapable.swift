import UIKit

public protocol TransitionCapable {
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}
