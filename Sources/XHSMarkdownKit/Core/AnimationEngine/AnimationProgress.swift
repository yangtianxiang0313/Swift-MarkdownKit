import Foundation
import CoreGraphics

public enum AnimationPhase: Equatable {
    case structure
    case content
    case completed
}

public struct AnimationProgress {
    public let version: Int
    public let phase: AnimationPhase
    public let displayedUnits: Int
    public let totalUnits: Int
    public let elapsedMilliseconds: Int
    public let currentContentHeight: CGFloat
    public let isRunning: Bool

    public init(
        version: Int,
        phase: AnimationPhase,
        displayedUnits: Int,
        totalUnits: Int,
        elapsedMilliseconds: Int,
        currentContentHeight: CGFloat,
        isRunning: Bool
    ) {
        self.version = version
        self.phase = phase
        self.displayedUnits = max(0, displayedUnits)
        self.totalUnits = max(0, totalUnits)
        self.elapsedMilliseconds = max(0, elapsedMilliseconds)
        self.currentContentHeight = max(0, currentContentHeight)
        self.isRunning = isRunning
    }
}
