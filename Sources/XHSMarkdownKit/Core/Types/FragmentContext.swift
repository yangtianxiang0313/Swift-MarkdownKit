import Foundation

public struct FragmentContext {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: ContextKey>(key: K.Type) -> K.Value {
        get {
            guard let value = storage[ObjectIdentifier(key)] as? K.Value else {
                return K.defaultValue
            }
            return value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    public func setting<K: ContextKey>(_ key: K.Type, to value: K.Value) -> FragmentContext {
        var copy = self
        copy[key] = value
        return copy
    }
}
