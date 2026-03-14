import UIKit

public final class SceneApplier {
    private struct ArrangedEntry {
        let view: UIView
        let spacingAfter: CGFloat
    }

    private let stackView: UIStackView

    public init(stackView: UIStackView) {
        self.stackView = stackView
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 0
    }

    @discardableResult
    public func apply(
        scene: RenderScene,
        maxWidth: CGFloat,
        managedViews: inout [String: UIView]
    ) -> CGFloat {
        let targetIDs = scene.componentNodeIDs()

        for (id, view) in managedViews where !targetIDs.contains(id) {
            if let container = view.superview as? UIStackView {
                container.removeArrangedSubview(view)
            }
            view.removeFromSuperview()
            managedViews.removeValue(forKey: id)
        }

        let topEntries = apply(nodes: scene.nodes, in: stackView, maxWidth: maxWidth, managedViews: &managedViews)
        sync(stack: stackView, entries: topEntries)

        stackView.layoutIfNeeded()
        let targetSize = CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height)
        let fitted = stackView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return max(0, ceil(fitted.height))
    }

    private func apply(
        nodes: [RenderScene.Node],
        in container: UIStackView,
        maxWidth: CGFloat,
        managedViews: inout [String: UIView]
    ) -> [ArrangedEntry] {
        var entries: [ArrangedEntry] = []

        for node in nodes {
            guard let component = node.component else {
                let passthrough = apply(nodes: node.children, in: container, maxWidth: maxWidth, managedViews: &managedViews)
                entries.append(contentsOf: passthrough)
                continue
            }

            let view = resolveView(for: node, component: component, managedViews: &managedViews)
            component.configure(view: view, maxWidth: maxWidth)

            if let nestedContainer = view as? SceneContainerView {
                let childMaxWidth = max(1, maxWidth - nestedContainer.sceneContentWidthReduction)
                let nestedEntries = apply(
                    nodes: node.children,
                    in: nestedContainer.sceneContentStackView,
                    maxWidth: childMaxWidth,
                    managedViews: &managedViews
                )
                sync(stack: nestedContainer.sceneContentStackView, entries: nestedEntries)
            } else if !node.children.isEmpty {
                let passthrough = apply(nodes: node.children, in: container, maxWidth: maxWidth, managedViews: &managedViews)
                entries.append(ArrangedEntry(view: view, spacingAfter: node.spacingAfter))
                entries.append(contentsOf: passthrough)
                continue
            }

            entries.append(ArrangedEntry(view: view, spacingAfter: node.spacingAfter))
        }

        return entries
    }

    private func resolveView(
        for node: RenderScene.Node,
        component: any SceneComponent,
        managedViews: inout [String: UIView]
    ) -> UIView {
        if let existing = managedViews[node.id] {
            let prototype = component.makeView()
            if type(of: existing) == type(of: prototype) {
                return existing
            }

            if let parent = existing.superview as? UIStackView {
                parent.removeArrangedSubview(existing)
            }
            existing.removeFromSuperview()
        }

        let view = component.makeView()
        managedViews[node.id] = view
        return view
    }

    private func sync(stack: UIStackView, entries: [ArrangedEntry]) {
        let targetViews = entries.map(\.view)
        let targetSet = Set(targetViews.map(ObjectIdentifier.init))

        for view in stack.arrangedSubviews where !targetSet.contains(ObjectIdentifier(view)) {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, entry) in entries.enumerated() {
            let view = entry.view

            if view.superview !== stack {
                if let oldParent = view.superview as? UIStackView {
                    oldParent.removeArrangedSubview(view)
                }
                view.removeFromSuperview()
                let insertion = min(index, stack.arrangedSubviews.count)
                stack.insertArrangedSubview(view, at: insertion)
            } else if let currentIndex = stack.arrangedSubviews.firstIndex(of: view), currentIndex != index {
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
                let insertion = min(index, stack.arrangedSubviews.count)
                stack.insertArrangedSubview(view, at: insertion)
            }

            stack.setCustomSpacing(entry.spacingAfter, after: view)
        }
    }
}
