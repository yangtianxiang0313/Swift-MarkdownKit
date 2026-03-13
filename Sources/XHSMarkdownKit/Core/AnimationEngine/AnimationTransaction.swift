import Foundation

public enum AnimationSubmitMode {
    case interruptCurrent
    case queueLatest
}

public struct AnimationTransaction {
    public let version: Int
    public let sourceFragmentsHint: [RenderFragment]
    public let targetFragments: [RenderFragment]
    public let submissionMode: AnimationSubmitMode
    private let planBuilder: ([RenderFragment], [RenderFragment]) -> AnimationPlan

    public init(
        version: Int,
        sourceFragmentsHint: [RenderFragment],
        targetFragments: [RenderFragment],
        submissionMode: AnimationSubmitMode = .interruptCurrent,
        planBuilder: @escaping ([RenderFragment], [RenderFragment]) -> AnimationPlan
    ) {
        self.version = version
        self.sourceFragmentsHint = sourceFragmentsHint
        self.targetFragments = targetFragments
        self.submissionMode = submissionMode
        self.planBuilder = planBuilder
    }

    public func makePlan(from sourceFragments: [RenderFragment]) -> AnimationPlan {
        planBuilder(sourceFragments, targetFragments)
    }
}
