import Foundation

public protocol FragmentDiffing {
    func diff(old: [RenderFragment], new: [RenderFragment]) -> [FragmentChange]
}
