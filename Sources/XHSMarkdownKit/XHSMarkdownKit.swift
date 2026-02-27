//
//  XHSMarkdownKit.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//  基于 XYMarkdown 的 Markdown 渲染库
//
//  V2 架构重构：
//  - 四层架构（输入层 → Markdown层 → Diff层 → UI层）
//  - 依赖注入（无单例）
//  - 协议优于基类
//  - 可插拔的渲染器和动画策略
//

// MARK: - Public API

@_exported import XYMarkdown

// MARK: - Version

/// XHSMarkdownKit 版本信息
public enum XHSMarkdownKitVersion {
    public static let major = 2
    public static let minor = 0
    public static let patch = 0
    
    public static var string: String {
        "\(major).\(minor).\(patch)"
    }
}

// MARK: - Core Types

// 以下类型通过各自的文件导出:
// - RenderContext (Core/RenderContext.swift)
// - RenderFragment, TextFragment, ViewFragment (Fragments/)
// - MarkdownRenderEngine (Engine/MarkdownRenderEngine.swift)
// - NodeRenderer (Engine/NodeRenderer.swift)
// - StreamableContent, FragmentAnimationDriver, TextRevealStrategy (Animation/)
// - MarkdownContainerView (Public/MarkdownContainerView.swift)
// - MarkdownKit (Public/MarkdownKit.swift)
// - StreamingAnimator (Streaming/StreamingAnimator.swift)
// - StreamingSpeedStrategy (Streaming/StreamingSpeedStrategy.swift)
//   - DefaultStreamingSpeedStrategy
//   - LinearSpeedStrategy
//   - ExponentialSpeedStrategy
//   - AdaptiveSpeedStrategy
//   - FixedSpeedStrategy
//   - InstantSpeedStrategy
