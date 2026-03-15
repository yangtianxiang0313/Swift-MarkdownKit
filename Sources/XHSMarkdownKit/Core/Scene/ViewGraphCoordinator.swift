import UIKit

public final class ViewGraphCoordinator {
    private let sceneApplier: SceneApplier
    private var managedViews: [String: UIView] = [:]
    var interactionHandler: ((RenderScene.Node, SceneInteractionPayload) -> Bool)? {
        didSet {
            sceneApplier.interactionHandler = interactionHandler
        }
    }

    public init(containerView: UIView) {
        self.sceneApplier = SceneApplier(containerView: containerView)
        self.sceneApplier.interactionHandler = interactionHandler
    }

    @discardableResult
    public func apply(scene: RenderScene, maxWidth: CGFloat) -> CGFloat {
        sceneApplier.apply(scene: scene, maxWidth: maxWidth, managedViews: &managedViews)
    }

    public func view(for entityID: String) -> UIView? {
        managedViews[entityID]
    }

    public func animateStructuralChanges(_ changes: [StructuralSceneChange]) {
        guard !changes.isEmpty else { return }

        let insertedIDs = Set(changes.compactMap { $0.kind == .insert ? $0.entityId : nil })
        for id in insertedIDs {
            guard let view = managedViews[id] else { continue }
            view.alpha = 0.45
            view.transform = CGAffineTransform(translationX: 0, y: 6)
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }
}
