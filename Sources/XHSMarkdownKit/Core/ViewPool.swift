import UIKit

public final class ViewPool {
    private var pool: [ReuseIdentifier: [UIView]] = [:]

    public init() {}

    public func dequeue(reuseIdentifier: ReuseIdentifier, factory: () -> UIView) -> UIView {
        if var views = pool[reuseIdentifier], !views.isEmpty {
            let view = views.removeLast()
            pool[reuseIdentifier] = views
            return view
        }
        return factory()
    }

    public func recycle(_ view: UIView, reuseIdentifier: ReuseIdentifier) {
        view.removeFromSuperview()
        pool[reuseIdentifier, default: []].append(view)
    }

    public func clear() {
        pool.removeAll()
    }
}
