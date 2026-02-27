import Foundation
import UIKit

// MARK: - EnterAnimationConfig

/// 进入动画配置
public struct EnterAnimationConfig {
    
    /// 动画时长
    public let duration: TimeInterval
    
    /// 动画类型
    public let type: EnterAnimationType
    
    /// 是否阻塞后续动画
    public let blocksSubsequent: Bool
    
    // MARK: - Initialization
    
    public init(
        duration: TimeInterval,
        type: EnterAnimationType,
        blocksSubsequent: Bool = true
    ) {
        self.duration = duration
        self.type = type
        self.blocksSubsequent = blocksSubsequent
    }
    
    // MARK: - Presets
    
    /// 默认（淡入，阻塞）
    public static let `default` = EnterAnimationConfig(
        duration: 0.2,
        type: .fadeIn,
        blocksSubsequent: true
    )
    
    /// 快速淡入（不阻塞）
    public static let quickFadeIn = EnterAnimationConfig(
        duration: 0.15,
        type: .fadeIn,
        blocksSubsequent: false
    )
    
    /// 上滑
    public static let slideUp = EnterAnimationConfig(
        duration: 0.25,
        type: .slideUp,
        blocksSubsequent: true
    )
    
    /// 展开
    public static let expand = EnterAnimationConfig(
        duration: 0.25,
        type: .expand,
        blocksSubsequent: true
    )
    
    /// 无动画
    public static let none = EnterAnimationConfig(
        duration: 0,
        type: .none,
        blocksSubsequent: false
    )
}

// MARK: - EnterAnimationType

/// 进入动画类型
public enum EnterAnimationType: Equatable {
    /// 淡入
    case fadeIn
    
    /// 从下方滑入
    case slideUp
    
    /// 高度展开
    case expand
    
    /// 无动画
    case none
    
    /// 自定义动画
    case custom((UIView, @escaping () -> Void) -> Void)
    
    public static func == (lhs: EnterAnimationType, rhs: EnterAnimationType) -> Bool {
        switch (lhs, rhs) {
        case (.fadeIn, .fadeIn), (.slideUp, .slideUp), (.expand, .expand), (.none, .none):
            return true
        case (.custom, .custom):
            return true  // 视为相同（无法比较闭包）
        default:
            return false
        }
    }
}

// MARK: - ContentAnimationConfig

/// 内容动画配置
public struct ContentAnimationConfig {
    
    /// 速率倍率（1.0 = 默认速度）
    public let speedMultiplier: CGFloat
    
    /// 动画粒度
    public let granularity: AnimationGranularity
    
    // MARK: - Initialization
    
    public init(
        speedMultiplier: CGFloat = 1.0,
        granularity: AnimationGranularity = .character
    ) {
        self.speedMultiplier = speedMultiplier
        self.granularity = granularity
    }
    
    // MARK: - Presets
    
    /// 文字（默认速度）
    public static let text = ContentAnimationConfig(
        speedMultiplier: 1.0,
        granularity: .character
    )
    
    /// 代码（1.5倍速）
    public static let code = ContentAnimationConfig(
        speedMultiplier: 1.5,
        granularity: .character
    )
    
    /// 思考内容（0.8倍速，更慢）
    public static let thinking = ContentAnimationConfig(
        speedMultiplier: 0.8,
        granularity: .character
    )
    
    /// 快速（2倍速）
    public static let fast = ContentAnimationConfig(
        speedMultiplier: 2.0,
        granularity: .character
    )
}

// MARK: - AnimationGranularity

/// 动画粒度
public enum AnimationGranularity {
    /// 逐字符
    case character
    
    /// 逐词
    case word
    
    /// 逐行
    case line
}

// MARK: - FragmentHeightMode

/// Fragment 高度计算模式
public enum FragmentHeightMode {
    /// 始终使用完整内容高度（当前行为）
    case fullContent

    /// 高度跟随动画进度：已完成的用完整高度，当前播放的用 displayedLength 对应高度
    case animationProgress
}

// MARK: - ContentUpdateResult

/// 内容更新结果
public struct ContentUpdateResult {
    
    /// 更新类型
    public let type: UpdateType
    
    /// 更新前长度
    public let previousLength: Int
    
    /// 更新后长度
    public let currentLength: Int
    
    // MARK: - UpdateType
    
    public enum UpdateType {
        /// 无变化
        case unchanged
        
        /// 纯追加
        case append(addedCount: Int)
        
        /// 有修改（中间内容变化）
        case modified(unchangedPrefixLength: Int)
        
        /// 被截短
        case truncated(newLength: Int)
    }
    
    // MARK: - Factories
    
    /// 无更新状态的初始值
    public static let zero = ContentUpdateResult(type: .unchanged, previousLength: 0, currentLength: 0)
    
    public static func unchanged(length: Int) -> ContentUpdateResult {
        ContentUpdateResult(type: .unchanged, previousLength: length, currentLength: length)
    }
    
    public static func append(addedCount: Int, previousLength: Int) -> ContentUpdateResult {
        ContentUpdateResult(
            type: .append(addedCount: addedCount),
            previousLength: previousLength,
            currentLength: previousLength + addedCount
        )
    }
    
    public static func modified(unchangedPrefixLength: Int, previousLength: Int, currentLength: Int) -> ContentUpdateResult {
        ContentUpdateResult(
            type: .modified(unchangedPrefixLength: unchangedPrefixLength),
            previousLength: previousLength,
            currentLength: currentLength
        )
    }
    
    public static func truncated(newLength: Int, previousLength: Int) -> ContentUpdateResult {
        ContentUpdateResult(
            type: .truncated(newLength: newLength),
            previousLength: previousLength,
            currentLength: newLength
        )
    }
}
