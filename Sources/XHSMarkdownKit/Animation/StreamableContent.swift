//
//  StreamableContent.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - StreamableContent

/// 流式动画能力协议
/// 任意 UIView 遵循即可参与 enter + reveal 动画
public protocol StreamableContent: UIView {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    func reveal(upTo length: Int)
    func updateContent(_ content: Any) -> ContentUpdateResult
    var enterAnimationConfig: EnterAnimationConfig? { get }
}

// MARK: - SimpleStreamableContent

/// 辅助协议：displayedLength=totalLength、reveal 空实现
/// 用于只需进入动画、无内容逐字的 View
public protocol SimpleStreamableContent: StreamableContent {}

extension SimpleStreamableContent {
    public var displayedLength: Int { totalLength }
    public func reveal(upTo length: Int) {}
    public func updateContent(_ content: Any) -> ContentUpdateResult {
        .unchanged(length: totalLength)
    }
    public var enterAnimationConfig: EnterAnimationConfig? { .default }
}
