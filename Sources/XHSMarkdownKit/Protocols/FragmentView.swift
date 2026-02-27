//
//  FragmentView.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - FragmentView

/// 支持静态高度计算的 Fragment View 协议
///
/// 高度计算逻辑放在 View 层，用户替换 View 实现时高度计算自动跟着替换。
/// Content 保持纯数据，不包含计算逻辑。
///
/// - Note: 与 FragmentConfigurable 互补，FragmentView 增加静态高度计算能力
public protocol FragmentView: UIView, FragmentConfigurable {
    
    associatedtype Content
    
    /// 静态高度计算（不依赖 View 实例）
    /// - Parameters:
    ///   - content: 完整内容（含原始数据 + 外部状态）
    ///   - maxWidth: 可用宽度
    ///   - theme: 主题
    /// - Returns: 预估高度
    static func calculateHeight(
        content: Content,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat
}
