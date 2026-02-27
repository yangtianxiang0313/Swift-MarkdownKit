import Foundation
import UIKit

// MARK: - RenderFragment Protocol

/// 渲染片段协议
/// 所有渲染输出都是 Fragment，形成有序的 Fragment 流
public protocol RenderFragment {
    /// 稳定的唯一标识符（基于结构位置，非内容）
    var fragmentId: String { get }
    
    /// 节点类型
    var nodeType: MarkdownNodeType { get }
}

// MARK: - Fragment 相等性比较

extension RenderFragment {
    /// 比较两个 Fragment 的 ID 是否相同
    public func hasSameId(as other: RenderFragment) -> Bool {
        fragmentId == other.fragmentId
    }
}
