import Foundation

public protocol ContextKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
