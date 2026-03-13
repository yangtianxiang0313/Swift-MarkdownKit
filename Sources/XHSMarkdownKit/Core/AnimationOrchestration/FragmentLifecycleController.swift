import Foundation

public final class FragmentLifecycleController {
    public enum State {
        case idle
        case entering
        case active
        case updating
        case exiting
        case removed
    }

    private var states: [String: State] = [:]

    public init() {}

    public func state(for fragmentId: String) -> State {
        states[fragmentId] ?? .idle
    }

    public func setState(_ state: State, for fragmentId: String) {
        states[fragmentId] = state
    }

    public func removeState(for fragmentId: String) {
        states.removeValue(forKey: fragmentId)
    }

    public func reset() {
        states.removeAll()
    }
}
