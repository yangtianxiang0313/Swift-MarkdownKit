import Foundation

public enum AnimationEffectStatus {
    case running
    case finished
}

public enum AnimationContextKey: String {
    case totalCharacters
    case displayedCharacters
    case revealedHeight
    case displayedLengthsByFragment
}

public final class AnimationExecutionContext {
    public weak var container: FragmentContaining?
    public let layoutCoordinator: LayoutCoordinator
    public let notifyLayoutChange: () -> Void
    private var storage: [AnimationContextKey: Any] = [:]

    public init(
        container: FragmentContaining,
        layoutCoordinator: LayoutCoordinator,
        notifyLayoutChange: @escaping () -> Void
    ) {
        self.container = container
        self.layoutCoordinator = layoutCoordinator
        self.notifyLayoutChange = notifyLayoutChange
    }

    public func setValue<T>(_ value: T, for key: AnimationContextKey) {
        storage[key] = value
    }

    public func value<T>(for key: AnimationContextKey, as type: T.Type = T.self) -> T? {
        storage[key] as? T
    }
}

public protocol StepEffect: AnyObject {
    func prepare(step: AnimationStep, context: AnimationExecutionContext)
    func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus
    func streamDidFinish(context: AnimationExecutionContext)
    func finish(context: AnimationExecutionContext)
    func cancel(context: AnimationExecutionContext)
}

public extension StepEffect {
    func streamDidFinish(context: AnimationExecutionContext) {}
    func finish(context: AnimationExecutionContext) {}
    func cancel(context: AnimationExecutionContext) {}
}
