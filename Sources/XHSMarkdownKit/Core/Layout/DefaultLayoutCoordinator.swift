import UIKit

public final class DefaultLayoutCoordinator: LayoutCoordinator {

    public init() {}

    public func apply(step: AnimationStep, to container: FragmentContaining) {
        let oldMap = Dictionary(uniqueKeysWithValues: step.oldFragments.map { ($0.fragmentId, $0) })

        for change in step.changes {
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
                let oldFragment = oldMap[fragmentId]

                if let preferring = oldFragment as? TransitionPreferring,
                   let transition = preferring.exitTransition {
                    transition.animateOut(view: view, completion: { [weak container] in
                        guard let factory = oldFragment as? FragmentViewFactory else {
                            view.removeFromSuperview()
                            return
                        }
                        container?.viewPool.recycle(view, reuseIdentifier: factory.reuseIdentifier)
                    })
                } else if let factory = oldFragment as? FragmentViewFactory {
                    container.viewPool.recycle(view, reuseIdentifier: factory.reuseIdentifier)
                } else {
                    view.removeFromSuperview()
                }

            case .update(_, let newFragment, let childChanges):
                guard let viewFactory = newFragment as? FragmentViewFactory,
                      let view = container.managedViews[newFragment.fragmentId] else { continue }

                viewFactory.configure(view)

                if let childChanges,
                   !childChanges.isEmpty,
                   let nestedContainer = view as? FragmentContaining,
                   let containerFragment = newFragment as? ContainerFragment {
                    nestedContainer.update(containerFragment.childFragments)
                }

            case .move:
                break
            }
        }

        for fragment in step.newFragments {
            if let view = container.managedViews[fragment.fragmentId] {
                container.containerView.bringSubviewToFront(view)
            }
        }

        relayout(
            fragments: step.newFragments,
            in: container,
            displayedLengthProvider: { fragment in
                (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
            }
        )
    }

    public func relayout(
        fragments: [RenderFragment],
        in container: FragmentContaining,
        displayedLengthProvider: (RenderFragment) -> Int
    ) {
        let width = container.containerView.bounds.width
        var y: CGFloat = 0

        for (index, fragment) in fragments.enumerated() {
            guard let view = container.managedViews[fragment.fragmentId] else { continue }
            let displayedLength = max(0, displayedLengthProvider(fragment))

            if displayedLength == 0 {
                view.isHidden = true
                view.frame = CGRect(x: 0, y: y, width: width, height: 0)
                continue
            } else {
                view.isHidden = false
            }

            let height: CGFloat
            if let estimatable = view as? HeightEstimatable {
                height = estimatable.estimatedHeight(atDisplayedLength: displayedLength, maxWidth: width)
            } else {
                height = view.bounds.height
            }

            view.frame = CGRect(x: 0, y: y, width: width, height: height)
            y += height
            if index < fragments.count - 1 {
                y += fragment.spacingAfter
            }
        }
    }
}
