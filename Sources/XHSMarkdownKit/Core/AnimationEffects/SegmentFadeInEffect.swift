import UIKit

/// A lightweight segment-based fade companion effect.
/// In UIKit-native rendering this effect acts as a timing helper and keeps
/// compatibility for future view-level alpha segment animation adapters.
public final class SegmentFadeInEffect: StepEffect {
    private let segmentSize: Int
    private let segmentDelay: TimeInterval
    private let minimumDuration: TimeInterval

    private var elapsed: TimeInterval = 0
    private var estimatedTotalDuration: TimeInterval = 0
    private var completed = false

    public init(segmentSize: Int = 14, segmentDelay: TimeInterval = 0.05, minimumDuration: TimeInterval = 0.2) {
        self.segmentSize = max(1, segmentSize)
        self.segmentDelay = max(0, segmentDelay)
        self.minimumDuration = max(0, minimumDuration)
    }

    public func prepare(step: AnimationStep, context: AnimationExecutionContext) {
        elapsed = 0
        completed = false

        let totalCharacters = step.newFragments.reduce(0) { partial, fragment in
            partial + ((fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1)
        }
        let segmentCount = max(1, Int(ceil(Double(totalCharacters) / Double(segmentSize))))
        estimatedTotalDuration = max(minimumDuration, Double(segmentCount - 1) * segmentDelay)

        if let container = context.container {
            var insertOrder = 0
            for change in step.changes {
                guard case .insert(let fragment, _) = change,
                      let view = container.managedViews[fragment.fragmentId] else { continue }

                view.alpha = 0
                UIView.animate(
                    withDuration: 0.35,
                    delay: Double(insertOrder) * segmentDelay,
                    options: [.curveEaseOut, .allowUserInteraction]
                ) {
                    view.alpha = 1
                }
                insertOrder += 1
            }
        }

        if estimatedTotalDuration == 0 {
            completed = true
        }
    }

    public func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus {
        if completed { return .finished }
        elapsed += max(0, deltaTime)
        if elapsed >= estimatedTotalDuration {
            completed = true
            return .finished
        }
        return .running
    }

    public func finish(context: AnimationExecutionContext) {
        completed = true
    }

    public func cancel(context: AnimationExecutionContext) {
        completed = true
    }
}
