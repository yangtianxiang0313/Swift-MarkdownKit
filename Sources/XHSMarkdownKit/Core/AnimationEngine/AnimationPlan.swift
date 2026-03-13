import Foundation

public struct AnimationPlan {
    public let steps: [AnimationStep]

    public init(steps: [AnimationStep]) {
        self.steps = steps
    }

    public static let empty = AnimationPlan(steps: [])
}
