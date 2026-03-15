import UIKit

public final class SceneApplier {
    private let containerView: UIView
    var interactionHandler: ((RenderScene.Node, SceneInteractionPayload) -> Bool)?

    public init(containerView: UIView) {
        self.containerView = containerView
        containerView.clipsToBounds = true
    }

    @discardableResult
    public func apply(
        scene: RenderScene,
        maxWidth: CGFloat,
        managedViews: inout [String: UIView]
    ) -> CGFloat {
        let targetIDs = scene.componentNodeIDs()

        for (id, view) in managedViews where !targetIDs.contains(id) {
            view.removeFromSuperview()
            managedViews.removeValue(forKey: id)
        }

        let result = layout(
            nodes: scene.nodes,
            in: containerView,
            originY: 0,
            maxWidth: max(1, maxWidth),
            managedViews: &managedViews
        )

        syncSubviewOrder(in: containerView, orderedViews: result.orderedViews)
        return max(0, ceil(result.endY))
    }

    private func layout(
        nodes: [RenderScene.Node],
        in parent: UIView,
        originY: CGFloat,
        maxWidth: CGFloat,
        managedViews: inout [String: UIView]
    ) -> LayoutResult {
        let resolvedMaxWidth = sanitize(maxWidth, fallback: 1, minimum: 1)
        var y = sanitize(originY, fallback: 0, minimum: 0)
        var orderedViews: [UIView] = []

        for node in nodes {
            guard let component = node.component else {
                let passthrough = layout(
                    nodes: node.children,
                    in: parent,
                    originY: y,
                    maxWidth: resolvedMaxWidth,
                    managedViews: &managedViews
                )
                y = sanitize(passthrough.endY, fallback: y, minimum: 0)
                orderedViews.append(contentsOf: passthrough.orderedViews)
                continue
            }

            let view = resolveView(for: node, component: component, parent: parent, managedViews: &managedViews)
            if let interactionView = view as? any SceneInteractionEmitting {
                interactionView.sceneInteractionHandler = { [weak self] payload in
                    self?.interactionHandler?(node, payload) ?? true
                }
            }
            component.configure(view: view, maxWidth: resolvedMaxWidth)

            let baseHeight = measuredHeight(for: view, width: resolvedMaxWidth)
            let spacingAfter = sanitize(node.spacingAfter, fallback: 0, minimum: 0)
            if node.kind == "codeBlock" {
                SceneDebugLogger.log(
                    "SceneApplier layout node=\(node.id) width=\(resolvedMaxWidth) y=\(y) baseHeight=\(baseHeight) spacing=\(spacingAfter)",
                    level: .verbose
                )
            }

            if let nestedContainer = view as? SceneContainerView {
                let insets = sanitize(nestedContainer.sceneContentInsets)
                let childMaxWidth = sanitize(resolvedMaxWidth - insets.left - insets.right, fallback: 1, minimum: 1)
                let childLayout = layout(
                    nodes: node.children,
                    in: nestedContainer.sceneContentContainerView,
                    originY: 0,
                    maxWidth: childMaxWidth,
                    managedViews: &managedViews
                )
                syncSubviewOrder(in: nestedContainer.sceneContentContainerView, orderedViews: childLayout.orderedViews)

                let childEndY = sanitize(childLayout.endY, fallback: 0, minimum: 0)
                let ownHeight = sanitize(max(baseHeight, insets.top + childEndY + insets.bottom), fallback: baseHeight, minimum: 1)
                view.frame = CGRect(x: 0, y: y, width: resolvedMaxWidth, height: ownHeight)
                nestedContainer.sceneContentContainerView.frame = CGRect(
                    x: insets.left,
                    y: insets.top,
                    width: childMaxWidth,
                    height: childEndY
                )

                orderedViews.append(view)
                y = sanitize(y + ownHeight + spacingAfter, fallback: y + ownHeight, minimum: 0)
                continue
            }

            view.frame = CGRect(x: 0, y: y, width: resolvedMaxWidth, height: baseHeight)
            orderedViews.append(view)
            y = sanitize(y + baseHeight + spacingAfter, fallback: y + baseHeight, minimum: 0)

            if !node.children.isEmpty {
                let passthrough = layout(
                    nodes: node.children,
                    in: parent,
                    originY: y,
                    maxWidth: resolvedMaxWidth,
                    managedViews: &managedViews
                )
                y = sanitize(passthrough.endY, fallback: y, minimum: 0)
                orderedViews.append(contentsOf: passthrough.orderedViews)
            }
        }

        return LayoutResult(endY: y, orderedViews: orderedViews)
    }

    private func resolveView(
        for node: RenderScene.Node,
        component: any SceneComponent,
        parent: UIView,
        managedViews: inout [String: UIView]
    ) -> UIView {
        if let existing = managedViews[node.id] {
            let prototype = component.makeView()
            if type(of: existing) == type(of: prototype) {
                if existing.superview !== parent {
                    existing.removeFromSuperview()
                    parent.addSubview(existing)
                }
                return existing
            }

            existing.removeFromSuperview()
        }

        let view = component.makeView()
        if view.superview !== parent {
            parent.addSubview(view)
        }
        managedViews[node.id] = view
        return view
    }

    private func measuredHeight(for view: UIView, width: CGFloat) -> CGFloat {
        let clampedWidth = sanitize(width, fallback: 1, minimum: 1)
        let target = CGSize(width: clampedWidth, height: CGFloat.greatestFiniteMagnitude)

        var measured = view.sizeThatFits(target).height
        if !measured.isFinite || measured <= 0 {
            let fitted = view.systemLayoutSizeFitting(
                CGSize(width: clampedWidth, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            measured = fitted.height
        }

        if !measured.isFinite || measured <= 0 {
            measured = view.intrinsicContentSize.height
        }

        if !measured.isFinite || measured <= 0 {
            measured = 1
        }
        let resolved = max(1, ceil(measured))
        if String(describing: type(of: view)).contains("CodeBlockSceneView") {
            SceneDebugLogger.log(
                "SceneApplier measured view=\(type(of: view)) width=\(clampedWidth) height=\(resolved)",
                level: .verbose
            )
        }
        return resolved
    }

    private func syncSubviewOrder(in container: UIView, orderedViews: [UIView]) {
        let targetIDs = Set(orderedViews.map(ObjectIdentifier.init))

        for subview in container.subviews where !targetIDs.contains(ObjectIdentifier(subview)) {
            subview.removeFromSuperview()
        }

        for (index, view) in orderedViews.enumerated() {
            if view.superview !== container {
                view.removeFromSuperview()
                container.addSubview(view)
            }
            if index == 0 {
                container.sendSubviewToBack(view)
            } else {
                container.bringSubviewToFront(view)
            }
        }
    }
}

private struct LayoutResult {
    let endY: CGFloat
    let orderedViews: [UIView]
}

private extension SceneApplier {
    func sanitize(_ value: CGFloat, fallback: CGFloat, minimum: CGFloat) -> CGFloat {
        let resolved = value.isFinite ? value : fallback
        return max(minimum, resolved)
    }

    func sanitize(_ insets: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, insets.top.isFinite ? insets.top : 0),
            left: max(0, insets.left.isFinite ? insets.left : 0),
            bottom: max(0, insets.bottom.isFinite ? insets.bottom : 0),
            right: max(0, insets.right.isFinite ? insets.right : 0)
        )
    }
}
