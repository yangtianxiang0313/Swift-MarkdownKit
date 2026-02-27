//
//  FragmentEvent.swift
//  XHSMarkdownKit
//

import Foundation

// MARK: - FragmentEventReporting

/// 支持事件上报的 View 协议
/// ContainerView 在 configure 后设置 onEvent，View 通过其上报用户交互
public protocol FragmentEventReporting: AnyObject {
    var onEvent: ((FragmentEvent) -> Void)? { get set }
}

// MARK: - FragmentEvent

/// Fragment 事件协议
/// View 通过 onEvent 上报，由 ContainerView.handleEvent 处理并更新 StateStore
public protocol FragmentEvent {
    var fragmentId: String { get }
}

// MARK: - CopyEvent

/// 代码块复制事件
public struct CopyEvent: FragmentEvent {
    public let fragmentId: String
    public let copiedText: String
    
    public init(fragmentId: String, copiedText: String) {
        self.fragmentId = fragmentId
        self.copiedText = copiedText
    }
}
