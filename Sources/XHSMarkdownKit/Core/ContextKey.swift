import Foundation
import UIKit

// MARK: - Context Key Protocol

/// 定义 RenderContext 中的值类型
/// 采用 SwiftUI Environment 模式，支持类型安全的扩展
///
/// 使用方式:
/// ```swift
/// // 1. 定义自己的 Key
/// enum MyCustomDepthKey: ContextKey {
///     static var defaultValue: Int { 0 }
/// }
///
/// // 2. 添加便捷访问器（可选）
/// extension RenderContext {
///     var myCustomDepth: Int { self[MyCustomDepthKey.self] }
/// }
///
/// // 3. 在渲染器中使用
/// let depth = context[MyCustomDepthKey.self]
/// let childContext = context.setting(MyCustomDepthKey.self, to: depth + 1)
/// ```
public protocol ContextKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
