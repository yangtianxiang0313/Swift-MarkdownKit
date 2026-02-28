import UIKit

public protocol FragmentViewFactory: RenderFragment {
    var reuseIdentifier: ReuseIdentifier { get }
    func makeView() -> UIView
    func configure(_ view: UIView)
}
