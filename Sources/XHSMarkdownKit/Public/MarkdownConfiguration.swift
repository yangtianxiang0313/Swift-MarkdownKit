//
//  MarkdownConfiguration.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit
import XYMarkdown

/// 渲染配置（V2 架构）
public struct MarkdownConfiguration {
    
    public static let `default` = MarkdownConfiguration()
    
    /// 可用渲染宽度（用于 UIView 型渲染器）
    public var maxWidth: CGFloat = .greatestFiniteMagnitude
    
    /// 是否启用蓝链改写
    public var enableRichLink: Bool = true
    
    /// 已知的自定义块节点标识符列表
    public var customBlockIdentifiers: Set<String> = []
    
    /// 已知的自定义行内节点标识符列表
    public var customInlineIdentifiers: Set<String> = []
    
    // MARK: - Fragment ID 策略
    
    /// Fragment ID 生成策略
    ///
    /// 不同策略在"稳定性"和"精确性"之间权衡：
    /// - `.structuralFingerprint`：基于 AST 位置，replace 时只更新变化的 fragment（默认）
    /// - `.sequentialIndex`：基于顺序索引，replace 时后续所有 fragment 都会 delete+insert
    /// - `.contentHash`：基于内容 hash，相同内容复用（适合内容重复的场景）
    public var fragmentIdStrategy: FragmentIdStrategy = .structuralFingerprint
    
    /// Fragment ID 生成策略枚举
    public enum FragmentIdStrategy {
        /// 结构指纹（默认）：基于节点类型 + 顶层块索引
        case structuralFingerprint
        
        /// 顺序索引（降级方案）：基于遍历顺序的递增索引
        case sequentialIndex
        
        /// 内容哈希：基于内容的 hash
        case contentHash
    }
    
    public init() {}
}

// MARK: - 便捷预设

public extension MarkdownConfiguration {
    /// 流式渲染配置
    static func streaming(maxWidth: CGFloat) -> MarkdownConfiguration {
        var config = MarkdownConfiguration()
        config.maxWidth = maxWidth
        config.fragmentIdStrategy = .structuralFingerprint
        return config
    }
}
