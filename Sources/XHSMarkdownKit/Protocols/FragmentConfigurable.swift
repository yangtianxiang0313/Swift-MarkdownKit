import Foundation
import UIKit

// MARK: - FragmentConfigurable Protocol

/// 可配置的 Fragment View 协议
///
/// 所有用于渲染 ViewFragment 的 View 都应实现此协议，
/// 提供统一的配置接口。
///
/// ## 使用示例
///
/// ```swift
/// class CodeBlockView: UIView, FragmentConfigurable {
///     func configure(content: Any, theme: MarkdownTheme) {
///         guard let codeContent = content as? CodeBlockContent else { return }
///         // 配置视图...
///     }
/// }
/// ```
///
/// ## 设计说明
///
/// - `content` 使用 `Any` 类型以保持灵活性，View 内部做类型转换
/// - `theme` 提供样式配置
/// - 高度由 ContainerView 通过 frame 设置，View 只负责内部布局
public protocol FragmentConfigurable: UIView {
    
    /// 配置视图
    /// - Parameters:
    ///   - content: 内容数据（具体类型由 View 自行转换）
    ///   - theme: 主题配置
    func configure(content: Any, theme: MarkdownTheme)
}
