import Foundation
import CoreGraphics

public struct AnimationProgress {
    public let version: Int
    public let completedSteps: Int
    public let totalSteps: Int
    public let isRunning: Bool
    public let displayedCharacters: Int?
    public let totalCharacters: Int?
    public let revealedHeight: CGFloat?

    public init(
        version: Int,
        completedSteps: Int,
        totalSteps: Int,
        isRunning: Bool,
        displayedCharacters: Int? = nil,
        totalCharacters: Int? = nil,
        revealedHeight: CGFloat? = nil
    ) {
        self.version = version
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.isRunning = isRunning
        self.displayedCharacters = displayedCharacters
        self.totalCharacters = totalCharacters
        self.revealedHeight = revealedHeight
    }
}
