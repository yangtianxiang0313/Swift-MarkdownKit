import Foundation

public enum SceneChangeKind: String {
    case insert
    case remove
    case update
    case move
}

public struct SceneChange {
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

public struct SceneDiff {
    public var changes: [SceneChange]

    public init(changes: [SceneChange]) {
        self.changes = changes
    }

    public var isEmpty: Bool {
        changes.isEmpty
    }
}

public protocol SceneDiffering {
    func diff(old: RenderScene, new: RenderScene) -> SceneDiff
}

public struct DefaultSceneDiffer: SceneDiffering {
    public init() {}

    public func diff(old: RenderScene, new: RenderScene) -> SceneDiff {
        let oldNodes = old.flattenRenderableNodes()
        let newNodes = new.flattenRenderableNodes()

        let oldIndexByID = Dictionary(uniqueKeysWithValues: oldNodes.enumerated().map { ($0.element.id, $0.offset) })
        let newIndexByID = Dictionary(uniqueKeysWithValues: newNodes.enumerated().map { ($0.element.id, $0.offset) })
        let oldByID = Dictionary(uniqueKeysWithValues: oldNodes.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.id, $0) })

        var changes: [SceneChange] = []

        for (index, node) in oldNodes.enumerated() where newIndexByID[node.id] == nil {
            changes.append(SceneChange(kind: .remove, entityId: node.id, fromIndex: index))
        }

        for (index, node) in newNodes.enumerated() where oldIndexByID[node.id] == nil {
            changes.append(SceneChange(kind: .insert, entityId: node.id, toIndex: index))
        }

        for id in Set(oldIndexByID.keys).intersection(newIndexByID.keys) {
            if let oldIndex = oldIndexByID[id], let newIndex = newIndexByID[id], oldIndex != newIndex {
                changes.append(SceneChange(kind: .move, entityId: id, fromIndex: oldIndex, toIndex: newIndex))
            }

            if let oldNode = oldByID[id], let newNode = newByID[id], oldNode != newNode {
                changes.append(SceneChange(kind: .update, entityId: id))
            }
        }

        let ordered = changes.sorted { lhs, rhs in
            if rank(lhs.kind) != rank(rhs.kind) {
                return rank(lhs.kind) < rank(rhs.kind)
            }
            let lp = lhs.toIndex ?? lhs.fromIndex ?? Int.max
            let rp = rhs.toIndex ?? rhs.fromIndex ?? Int.max
            if lp != rp { return lp < rp }
            return lhs.entityId < rhs.entityId
        }

        return SceneDiff(changes: ordered)
    }

    private func rank(_ kind: SceneChangeKind) -> Int {
        switch kind {
        case .remove: return 0
        case .update: return 1
        case .move: return 2
        case .insert: return 3
        }
    }
}
