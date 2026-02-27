import Foundation
import UIKit

// MARK: - MarkdownRenderResult

/// 渲染结果
/// 包含有序的 Fragment 流
public struct MarkdownRenderResult {
    
    /// 渲染输出的 Fragment 数组（有序）
    public let fragments: [RenderFragment]
    
    /// 原始文本
    public let sourceText: String
    
    /// 渲染模式
    public let mode: RenderMode
    
    // MARK: - Initialization
    
    public init(
        fragments: [RenderFragment],
        sourceText: String = "",
        mode: RenderMode = .normal
    ) {
        self.fragments = fragments
        self.sourceText = sourceText
        self.mode = mode
    }
}

// MARK: - Convenience

extension MarkdownRenderResult {
    
    /// Fragment 数量
    public var count: Int {
        fragments.count
    }
    
    /// 是否为空
    public var isEmpty: Bool {
        fragments.isEmpty
    }
    
    /// 所有 TextFragment
    public var textFragments: [TextFragment] {
        fragments.compactMap { $0 as? TextFragment }
    }
    
    /// 所有 ViewFragment
    public var viewFragments: [ViewFragment] {
        fragments.compactMap { $0 as? ViewFragment }
    }
    
    /// 获取指定 ID 的 Fragment
    public func fragment(withId id: String) -> RenderFragment? {
        fragments.first { $0.fragmentId == id }
    }
    
    /// 便捷属性：合并所有文本片段为单一 NSAttributedString
    /// 适用于简单场景（无 UIView 混排时直接赋值给 UILabel）
    public var attributedString: NSAttributedString {
        let result = NSMutableAttributedString()
        for fragment in textFragments {
            if result.length > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(fragment.attributedString)
        }
        return result
    }
    
    /// 便捷属性：是否包含 UIView 片段
    public var hasViewFragments: Bool {
        viewFragments.count > 0
    }
}

// MARK: - RenderMode

/// 渲染模式
public enum RenderMode {
    /// 普通模式：完整渲染
    case normal
    
    /// 流式模式：启用预处理（补全未闭合标记）
    case streaming
}
