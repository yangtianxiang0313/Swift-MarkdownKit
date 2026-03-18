import Foundation

public struct AnimationEntityKey: Hashable, Sendable {
    public let documentId: String
    public let entityId: String

    public init(documentId: String, entityId: String) {
        self.documentId = documentId
        self.entityId = entityId
    }
}

public struct AnimationEntityProgressState: Sendable, Equatable {
    public let displayedUnits: Int
    public let stableUnits: Int
    public let targetUnits: Int
    public let lastVersion: Int

    public init(
        displayedUnits: Int,
        stableUnits: Int,
        targetUnits: Int,
        lastVersion: Int
    ) {
        let clampedDisplayed = max(0, displayedUnits)
        let clampedStable = min(clampedDisplayed, max(0, stableUnits))
        let clampedTarget = max(clampedDisplayed, max(0, targetUnits))
        self.displayedUnits = clampedDisplayed
        self.stableUnits = clampedStable
        self.targetUnits = clampedTarget
        self.lastVersion = max(0, lastVersion)
    }
}

public protocol AnimationStateBackingStore: AnyObject {
    func prepareAnimationState(
        documentID: String,
        revealUnitsByEntity: [String: Int]
    )

    func animationState(for key: AnimationEntityKey) -> AnimationEntityProgressState?

    func animationStates(documentID: String) -> [AnimationEntityKey: AnimationEntityProgressState]

    func setAnimationState(_ state: AnimationEntityProgressState, for key: AnimationEntityKey)

    func removeAnimationStates(documentID: String)
}
