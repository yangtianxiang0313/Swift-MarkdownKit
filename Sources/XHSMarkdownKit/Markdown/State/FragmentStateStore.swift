import Foundation

public final class FragmentStateStore {
    private var storage: [String: Any] = [:]

    public init() {}

    public func get<T>(key: String, as type: T.Type) -> T? {
        storage[key] as? T
    }

    public func set<T>(key: String, value: T) {
        storage[key] = value
    }

    public func remove(key: String) {
        storage.removeValue(forKey: key)
    }

    public func clear() {
        storage.removeAll()
    }
}
