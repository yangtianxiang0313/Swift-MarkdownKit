//
//  FragmentState.swift
//  XHSMarkdownKit
//

import Foundation

// MARK: - FragmentState

/// Fragment 外部状态协议
/// 每种状态类型有唯一标识和默认值，用于跨 render 周期持久化
public protocol FragmentState {
    
    /// 状态类型标识（用于存储时的 key）
    static var stateType: String { get }
    
    /// 默认状态（首次访问或未设置时返回）
    static var defaultState: Self { get }
}
