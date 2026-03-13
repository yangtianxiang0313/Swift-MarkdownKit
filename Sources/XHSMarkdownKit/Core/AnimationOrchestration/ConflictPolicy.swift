import Foundation

public enum AnimationSchedulingMode {
    case groupedByPhase
    case serialByChange
    case parallelByChange
}

public struct ConflictPolicy {
    public var defaultEffectKey: AnimationEffectKey
    public var schedulingMode: AnimationSchedulingMode
    public var submissionMode: AnimationSubmitMode

    public init(
        defaultEffectKey: AnimationEffectKey = .instant,
        schedulingMode: AnimationSchedulingMode = .groupedByPhase,
        submissionMode: AnimationSubmitMode = .interruptCurrent
    ) {
        self.defaultEffectKey = defaultEffectKey
        self.schedulingMode = schedulingMode
        self.submissionMode = submissionMode
    }

    public static let `default` = ConflictPolicy()
}
