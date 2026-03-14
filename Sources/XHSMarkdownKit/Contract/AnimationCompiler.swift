import Foundation

extension MarkdownContract {
    public struct CompiledAnimationPlan: Sendable, Equatable, Codable {
        public var intents: [AnimationIntent]
        public var timeline: TimelineGraph

        public init(intents: [AnimationIntent], timeline: TimelineGraph) {
            self.intents = intents
            self.timeline = timeline
        }
    }

    public protocol RenderModelAnimationCompiler {
        func compile(old: RenderModel, new: RenderModel, diff: RenderModelDiff) -> CompiledAnimationPlan
    }

    public struct DefaultRenderModelAnimationCompiler: RenderModelAnimationCompiler {
        public init() {}

        public func compile(old: RenderModel, new: RenderModel, diff: RenderModelDiff) -> CompiledAnimationPlan {
            let flatChanges = diff.flattenedChanges

            var intents: [AnimationIntent] = []
            var tracks: [TimelineTrack] = []
            var structureTrackIDs: [String] = []
            var contentTrackIDs: [String] = []

            intents.reserveCapacity(flatChanges.count)
            tracks.reserveCapacity(flatChanges.count)

            for (index, change) in flatChanges.enumerated() {
                let trackID = "track.\(index)"
                tracks.append(
                    TimelineTrack(
                        id: trackID,
                        entityIds: [change.nodeId],
                        metadata: ["changeType": .string(change.type.rawValue)]
                    )
                )

                let intent = AnimationIntent(
                    entityId: change.nodeId,
                    type: change.type.rawValue,
                    from: change.fromPath.map(pathValue),
                    to: change.toPath.map(pathValue),
                    params: params(for: change)
                )
                intents.append(intent)

                switch change.type {
                case .insert, .remove, .move:
                    structureTrackIDs.append(trackID)
                case .update:
                    contentTrackIDs.append(trackID)
                }
            }

            var phases: [TimelinePhase] = []
            var constraints: [TimelineConstraint] = []

            if !structureTrackIDs.isEmpty {
                phases.append(
                    TimelinePhase(
                        id: "phase.structure",
                        name: "structure",
                        trackIds: structureTrackIDs,
                        metadata: ["effectKey": .string("segmentFade")]
                    )
                )
            }

            if !contentTrackIDs.isEmpty {
                phases.append(
                    TimelinePhase(
                        id: "phase.content",
                        name: "content",
                        trackIds: contentTrackIDs,
                        metadata: ["effectKey": .string("typing")]
                    )
                )
            }

            if phases.contains(where: { $0.id == "phase.structure" }) && phases.contains(where: { $0.id == "phase.content" }) {
                constraints.append(
                    TimelineConstraint(
                        kind: "after",
                        from: "phase.structure",
                        to: "phase.content"
                    )
                )
            }

            let timeline = TimelineGraph(
                schemaVersion: MarkdownContract.schemaVersion,
                tracks: tracks,
                phases: phases,
                constraints: constraints,
                metadata: [
                    "oldDocumentId": .string(old.documentId),
                    "newDocumentId": .string(new.documentId),
                    "changeCount": .int(flatChanges.count)
                ]
            )

            return CompiledAnimationPlan(intents: intents, timeline: timeline)
        }

        private func params(for change: RenderModelChange) -> [String: Value] {
            var params: [String: Value] = [:]
            params["changeType"] = .string(change.type.rawValue)

            if let oldBlock = change.oldBlock {
                params["oldKind"] = .string(oldBlock.kind.rawValue)
            }
            if let newBlock = change.newBlock {
                params["newKind"] = .string(newBlock.kind.rawValue)
            }
            if !change.childChanges.isEmpty {
                params["childChangeCount"] = .int(change.childChanges.count)
            }

            return params
        }

        private func pathValue(_ path: [Int]) -> Value {
            .array(path.map(Value.int))
        }
    }
}
