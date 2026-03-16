import Foundation

public struct RenderExecutionPlan {
    public struct Stage {
        public let id: String
        public let phase: AnimationPhase
        public let effectKey: AnimationEffectKey
        public let structuralChanges: [StructuralSceneChange]
        public let contentChanges: [ContentSceneChange]

        public init(
            id: String,
            phase: AnimationPhase,
            effectKey: AnimationEffectKey,
            structuralChanges: [StructuralSceneChange] = [],
            contentChanges: [ContentSceneChange] = []
        ) {
            self.id = id
            self.phase = phase
            self.effectKey = effectKey
            self.structuralChanges = structuralChanges
            self.contentChanges = contentChanges
        }

        public var isEmpty: Bool {
            structuralChanges.isEmpty && contentChanges.isEmpty
        }
    }

    public let stages: [Stage]

    public init(stages: [Stage]) {
        self.stages = stages.filter { !$0.isEmpty }
    }

    public static let empty = RenderExecutionPlan(stages: [])
    public var isEmpty: Bool { stages.isEmpty }
}
