import Foundation

public protocol ProgressivelyRevealable: RenderFragment {
    var totalContentLength: Int { get }
}
