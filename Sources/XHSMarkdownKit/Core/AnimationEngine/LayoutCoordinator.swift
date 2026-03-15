import UIKit

public final class LayoutCoordinator {
    private let changeThreshold: CGFloat
    private var lastPublishedHeight: CGFloat?

    public init(changeThreshold: CGFloat = 1) {
        self.changeThreshold = max(0, changeThreshold)
    }

    public func publishFrame(
        version: Int,
        phase: AnimationPhase,
        displayedUnits: Int,
        totalUnits: Int,
        elapsedMilliseconds: Int,
        isRunning: Bool,
        measureHeight: () -> CGFloat,
        onProgress: ((AnimationProgress) -> Void)?,
        onHeightChange: ((CGFloat) -> Void)?
    ) {
        let height = max(0, measureHeight())
        if shouldPublishHeight(height) {
            lastPublishedHeight = height
            onHeightChange?(height)
        }

        onProgress?(AnimationProgress(
            version: version,
            phase: phase,
            displayedUnits: displayedUnits,
            totalUnits: totalUnits,
            elapsedMilliseconds: elapsedMilliseconds,
            currentContentHeight: height,
            isRunning: isRunning
        ))
    }

    public func forcePublishFinalHeight(
        version: Int,
        measureHeight: () -> CGFloat,
        onProgress: ((AnimationProgress) -> Void)?,
        onHeightChange: ((CGFloat) -> Void)?
    ) {
        let height = max(0, measureHeight())
        lastPublishedHeight = height
        onHeightChange?(height)
        onProgress?(AnimationProgress(
            version: version,
            phase: .completed,
            displayedUnits: 0,
            totalUnits: 0,
            elapsedMilliseconds: 0,
            currentContentHeight: height,
            isRunning: false
        ))
    }

    private func shouldPublishHeight(_ height: CGFloat) -> Bool {
        guard let lastPublishedHeight else { return true }
        return abs(height - lastPublishedHeight) >= changeThreshold
    }
}
