import UIKit

public final class InstantDriver: AnimationDriver {

    public var onAnimationComplete: (() -> Void)?
    public var onLayoutChange: (() -> Void)?

    public init() {}

    public func apply(changes: [FragmentChange], fragments: [RenderFragment], to container: FragmentContaining) {
        for change in changes {
            switch change {
            case .insert(let fragment, _):
                guard let viewFactory = fragment as? FragmentViewFactory else { continue }
                let view = container.viewPool.dequeue(
                    reuseIdentifier: viewFactory.reuseIdentifier,
                    factory: { viewFactory.makeView() }
                )
                viewFactory.configure(view)
                container.containerView.addSubview(view)
                container.managedViews[fragment.fragmentId] = view

                if let preferring = fragment as? TransitionPreferring,
                   let transition = preferring.enterTransition {
                    transition.animateIn(view: view, completion: {})
                }

            case .remove(let fragmentId, _):
                guard let view = container.managedViews.removeValue(forKey: fragmentId) else { continue }
                let fragment = fragments.first { $0.fragmentId == fragmentId }
                if let preferring = fragment as? TransitionPreferring,
                   let transition = preferring.exitTransition {
                    transition.animateOut(view: view, completion: { [weak container] in
                        guard let factory = fragment as? FragmentViewFactory else { return }
                        container?.viewPool.recycle(view, reuseIdentifier: factory.reuseIdentifier)
                    })
                } else {
                    if let factory = fragment as? FragmentViewFactory {
                        container.viewPool.recycle(view, reuseIdentifier: factory.reuseIdentifier)
                    } else {
                        view.removeFromSuperview()
                    }
                }

            case .update(_, let newFragment, let childChanges):
                guard let viewFactory = newFragment as? FragmentViewFactory,
                      let view = container.managedViews[newFragment.fragmentId] else { continue }
                viewFactory.configure(view)

                if let childChanges = childChanges,
                   let nestedContainer = view as? FragmentContaining,
                   let containerFrag = newFragment as? ContainerFragment {
                    nestedContainer.animationDriver.apply(
                        changes: childChanges,
                        fragments: containerFrag.childFragments,
                        to: nestedContainer
                    )
                }

            case .move:
                break
            }
        }

        relayout(fragments: fragments, container: container)
    }

    public func streamDidFinish() {
        onAnimationComplete?()
    }

    public func finishAll() {
        onAnimationComplete?()
    }

    private func relayout(fragments: [RenderFragment], container: FragmentContaining) {
        let width = container.containerView.bounds.width
        var y: CGFloat = 0

        for (i, fragment) in fragments.enumerated() {
            guard let view = container.managedViews[fragment.fragmentId] else { continue }
            let height: CGFloat
            if let estimatable = view as? HeightEstimatable {
                let displayedLength = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
                height = estimatable.estimatedHeight(atDisplayedLength: displayedLength, maxWidth: width)
            } else {
                height = view.bounds.height
            }
            view.frame = CGRect(x: 0, y: y, width: width, height: height)
            y += height
            if i < fragments.count - 1 {
                y += fragment.spacingAfter
            }
        }
    }
}
