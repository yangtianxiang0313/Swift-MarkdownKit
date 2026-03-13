import Foundation

public protocol LayoutCoordinator {
    func apply(step: AnimationStep, to container: FragmentContaining)
    func relayout(
        fragments: [RenderFragment],
        in container: FragmentContaining,
        displayedLengthProvider: (RenderFragment) -> Int
    )
}
