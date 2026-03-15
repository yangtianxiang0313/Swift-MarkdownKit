import Foundation

public struct StructuralSceneChange {
    public var kind: SceneChangeKind
    public var entityId: String
    public var fromIndex: Int?
    public var toIndex: Int?

    public init(kind: SceneChangeKind, entityId: String, fromIndex: Int? = nil, toIndex: Int? = nil) {
        self.kind = kind
        self.entityId = entityId
        self.fromIndex = fromIndex
        self.toIndex = toIndex
    }
}

public struct ContentSceneChange {
    public var entityId: String
    public var stableUnits: Int
    public var targetUnits: Int
    public var inserted: Bool

    public init(entityId: String, stableUnits: Int, targetUnits: Int, inserted: Bool) {
        self.entityId = entityId
        self.stableUnits = max(0, stableUnits)
        self.targetUnits = max(0, targetUnits)
        self.inserted = inserted
    }

    public var deltaUnits: Int {
        max(0, targetUnits - stableUnits)
    }
}

public struct SceneDelta {
    public var structuralChanges: [StructuralSceneChange]
    public var contentChanges: [ContentSceneChange]

    public init(structuralChanges: [StructuralSceneChange], contentChanges: [ContentSceneChange]) {
        self.structuralChanges = structuralChanges
        self.contentChanges = contentChanges
    }

    public var isEmpty: Bool {
        structuralChanges.isEmpty && contentChanges.isEmpty
    }
}

public protocol SceneDeltaBuilding {
    func makeDelta(old: RenderScene, new: RenderScene, diff: SceneDiff) -> SceneDelta
}

public struct DefaultSceneDeltaBuilder: SceneDeltaBuilding {
    public init() {}

    public func makeDelta(old: RenderScene, new: RenderScene, diff: SceneDiff) -> SceneDelta {
        guard !diff.isEmpty else {
            return SceneDelta(structuralChanges: [], contentChanges: [])
        }

        var structural: [StructuralSceneChange] = []
        var content: [ContentSceneChange] = []

        for change in diff.changes {
            let oldNode = old.componentNodeByID(change.entityId)
            let newNode = new.componentNodeByID(change.entityId)

            switch change.kind {
            case .insert:
                structural.append(StructuralSceneChange(
                    kind: change.kind,
                    entityId: change.entityId,
                    fromIndex: change.fromIndex,
                    toIndex: change.toIndex
                ))
                if let reveal = newNode?.component as? any RevealAnimatableComponent,
                   reveal.revealUnitCount > 0 {
                    content.append(ContentSceneChange(
                        entityId: change.entityId,
                        stableUnits: 0,
                        targetUnits: reveal.revealUnitCount,
                        inserted: true
                    ))
                }

            case .remove, .move:
                structural.append(StructuralSceneChange(
                    kind: change.kind,
                    entityId: change.entityId,
                    fromIndex: change.fromIndex,
                    toIndex: change.toIndex
                ))

            case .update:
                let oldReveal = oldNode?.component as? any RevealAnimatableComponent
                let newReveal = newNode?.component as? any RevealAnimatableComponent

                if let newReveal {
                    let stableUnits = oldReveal?.revealUnitCount ?? 0
                    content.append(ContentSceneChange(
                        entityId: change.entityId,
                        stableUnits: stableUnits,
                        targetUnits: newReveal.revealUnitCount,
                        inserted: oldNode == nil
                    ))
                } else {
                    structural.append(StructuralSceneChange(
                        kind: change.kind,
                        entityId: change.entityId,
                        fromIndex: change.fromIndex,
                        toIndex: change.toIndex
                    ))
                }
            }
        }

        // Keep only meaningful content animations.
        content = content.filter { $0.deltaUnits > 0 }

        return SceneDelta(structuralChanges: structural, contentChanges: content)
    }
}
