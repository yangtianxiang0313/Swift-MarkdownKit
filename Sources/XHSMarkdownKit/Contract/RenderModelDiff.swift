import Foundation

extension MarkdownContract {
    public enum RenderModelChangeType: String, Sendable, Equatable, Codable {
        case insert
        case remove
        case update
        case move
    }

    public struct RenderModelChange: Sendable, Equatable, Codable {
        public var type: RenderModelChangeType
        public var nodeId: String
        public var fromPath: [Int]?
        public var toPath: [Int]?
        public var oldBlock: RenderBlock?
        public var newBlock: RenderBlock?
        public var childChanges: [RenderModelChange]

        public init(
            type: RenderModelChangeType,
            nodeId: String,
            fromPath: [Int]? = nil,
            toPath: [Int]? = nil,
            oldBlock: RenderBlock? = nil,
            newBlock: RenderBlock? = nil,
            childChanges: [RenderModelChange] = []
        ) {
            self.type = type
            self.nodeId = nodeId
            self.fromPath = fromPath
            self.toPath = toPath
            self.oldBlock = oldBlock
            self.newBlock = newBlock
            self.childChanges = childChanges
        }
    }

    public struct RenderModelDiff: Sendable, Equatable, Codable {
        public var schemaVersion: Int
        public var oldDocumentId: String
        public var newDocumentId: String
        public var changes: [RenderModelChange]

        public init(
            schemaVersion: Int = MarkdownContract.schemaVersion,
            oldDocumentId: String,
            newDocumentId: String,
            changes: [RenderModelChange]
        ) {
            self.schemaVersion = schemaVersion
            self.oldDocumentId = oldDocumentId
            self.newDocumentId = newDocumentId
            self.changes = changes
        }

        public var isEmpty: Bool {
            changes.isEmpty
        }

        public var flattenedChanges: [RenderModelChange] {
            flatten(changes)
        }

        private func flatten(_ input: [RenderModelChange]) -> [RenderModelChange] {
            input.flatMap { change in
                [change] + flatten(change.childChanges)
            }
        }
    }

    public protocol RenderModelDiffer {
        func diff(old: RenderModel, new: RenderModel) -> RenderModelDiff
    }

    public struct DefaultRenderModelDiffer: RenderModelDiffer {
        public init() {}

        public func diff(old: RenderModel, new: RenderModel) -> RenderModelDiff {
            let changes = diffBlocks(old.blocks, new.blocks, parentPath: [])
            return RenderModelDiff(
                schemaVersion: MarkdownContract.schemaVersion,
                oldDocumentId: old.documentId,
                newDocumentId: new.documentId,
                changes: changes
            )
        }

        private func diffBlocks(
            _ oldBlocks: [RenderBlock],
            _ newBlocks: [RenderBlock],
            parentPath: [Int]
        ) -> [RenderModelChange] {
            let oldIndexById = makeIndexMap(oldBlocks)
            let newIndexById = makeIndexMap(newBlocks)

            let removed = oldBlocks.enumerated()
                .filter { newIndexById[$0.element.id] == nil }
                .sorted { $0.offset > $1.offset }
                .map { index, block in
                    RenderModelChange(
                        type: .remove,
                        nodeId: block.id,
                        fromPath: parentPath + [index],
                        oldBlock: block
                    )
                }

            let inserted = newBlocks.enumerated()
                .filter { oldIndexById[$0.element.id] == nil }
                .sorted { $0.offset < $1.offset }
                .map { index, block in
                    RenderModelChange(
                        type: .insert,
                        nodeId: block.id,
                        toPath: parentPath + [index],
                        newBlock: block
                    )
                }

            let commonIds = Set(oldIndexById.keys).intersection(newIndexById.keys).sorted()

            let moved = commonIds.compactMap { id -> RenderModelChange? in
                guard let oldIndex = oldIndexById[id], let newIndex = newIndexById[id], oldIndex != newIndex else {
                    return nil
                }
                let oldBlock = oldBlocks[oldIndex]
                let newBlock = newBlocks[newIndex]
                return RenderModelChange(
                    type: .move,
                    nodeId: id,
                    fromPath: parentPath + [oldIndex],
                    toPath: parentPath + [newIndex],
                    oldBlock: oldBlock,
                    newBlock: newBlock
                )
            }

            let updated = commonIds.compactMap { id -> RenderModelChange? in
                guard let oldIndex = oldIndexById[id], let newIndex = newIndexById[id] else {
                    return nil
                }

                let oldBlock = oldBlocks[oldIndex]
                let newBlock = newBlocks[newIndex]
                let childChanges = diffBlocks(oldBlock.children, newBlock.children, parentPath: parentPath + [newIndex])

                let changed = oldBlock != newBlock || !childChanges.isEmpty
                guard changed else { return nil }

                return RenderModelChange(
                    type: .update,
                    nodeId: id,
                    fromPath: parentPath + [oldIndex],
                    toPath: parentPath + [newIndex],
                    oldBlock: oldBlock,
                    newBlock: newBlock,
                    childChanges: childChanges
                )
            }

            return removed + moved + updated + inserted
        }

        private func makeIndexMap(_ blocks: [RenderBlock]) -> [String: Int] {
            var map: [String: Int] = [:]
            map.reserveCapacity(blocks.count)
            for (index, block) in blocks.enumerated() where map[block.id] == nil {
                map[block.id] = index
            }
            return map
        }
    }
}
