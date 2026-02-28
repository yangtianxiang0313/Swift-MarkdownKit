import Foundation

public enum FragmentChange {
    case insert(fragment: RenderFragment, at: Int)
    case remove(fragmentId: String, at: Int)
    case update(old: RenderFragment, new: RenderFragment, childChanges: [FragmentChange]?)
    case move(fragmentId: String, from: Int, to: Int)
}
