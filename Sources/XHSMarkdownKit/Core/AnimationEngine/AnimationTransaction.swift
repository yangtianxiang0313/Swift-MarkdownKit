import Foundation

public enum AnimationSubmitMode {
    case interruptCurrent
    case queueLatest
}

public struct AnimationTransaction {
    public let version: Int
    public let sourceSceneHint: RenderScene
    public let targetScene: RenderScene
    public let submissionMode: AnimationSubmitMode
    private let planBuilder: (RenderScene, RenderScene) -> AnimationPlan

    public init(
        version: Int,
        sourceSceneHint: RenderScene,
        targetScene: RenderScene,
        submissionMode: AnimationSubmitMode = .interruptCurrent,
        planBuilder: @escaping (RenderScene, RenderScene) -> AnimationPlan
    ) {
        self.version = version
        self.sourceSceneHint = sourceSceneHint
        self.targetScene = targetScene
        self.submissionMode = submissionMode
        self.planBuilder = planBuilder
    }

    public func makePlan(from sourceScene: RenderScene) -> AnimationPlan {
        planBuilder(sourceScene, targetScene)
    }
}
