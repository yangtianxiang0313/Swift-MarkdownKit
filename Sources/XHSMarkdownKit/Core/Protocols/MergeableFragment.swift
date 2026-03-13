import CoreGraphics
import Foundation

public protocol MergeableFragment: RenderFragment {
    func canMerge(with other: RenderFragment) -> Bool
    func merged(with other: RenderFragment, interFragmentSpacing: CGFloat) -> RenderFragment
}
