import Foundation

public enum FragmentEvent {
    case codeCopied(stateKey: String)
    case custom(name: String, payload: Any?)
}
