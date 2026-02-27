//
//  CodeBlockInteractionState.swift
//  XHSMarkdownKit
//

import Foundation

// MARK: - CodeBlockInteractionState

/// 代码块交互状态（如复制成功提示）
public struct CodeBlockInteractionState: FragmentState {
    
    public static var stateType: String { "codeBlockInteraction" }
    
    public static var defaultState: Self {
        CodeBlockInteractionState(isCopied: false)
    }
    
    public var isCopied: Bool
    
    public init(isCopied: Bool = false) {
        self.isCopied = isCopied
    }
}
