import Foundation
import UIKit

// MARK: - FragmentAnimationDriverProvider

/// Driver 工厂协议（替代闭包）
public protocol FragmentAnimationDriverProvider {
    func makeDriver() -> FragmentAnimationDriver
}

// MARK: - TextRevealStrategyProvider

/// Reveal 策略工厂协议（替代闭包）
public protocol TextRevealStrategyProvider {
    func makeStrategy(for target: TextDisplayTarget) -> TextRevealStrategy
}

// MARK: - DefaultInstantDriverProvider

public struct DefaultInstantDriverProvider: FragmentAnimationDriverProvider {
    public init() {}
    public func makeDriver() -> FragmentAnimationDriver { InstantAnimationDriver() }
}

// MARK: - SubstringRevealStrategyProvider

public struct SubstringRevealStrategyProvider: TextRevealStrategyProvider {
    public init() {}
    public func makeStrategy(for target: TextDisplayTarget) -> TextRevealStrategy {
        SubstringRevealStrategy(targetView: target)
    }
}

// MARK: - StreamAnimatorProvider

public struct StreamAnimatorProvider: FragmentAnimationDriverProvider {
    public let enterAnimationExecutor: EnterAnimationExecutor
    public let revealSpeedStrategy: RevealSpeedStrategy
    public let fragmentHeightMode: FragmentHeightMode
    public let baseCharsPerFrame: Int
    public let globalSpeedMultiplier: CGFloat

    public init(
        enterAnimationExecutor: EnterAnimationExecutor = DefaultEnterAnimationExecutor(),
        revealSpeedStrategy: RevealSpeedStrategy = LinearRevealSpeedStrategy(),
        fragmentHeightMode: FragmentHeightMode = .fullContent,
        baseCharsPerFrame: Int = 3,
        globalSpeedMultiplier: CGFloat = 1.0
    ) {
        self.enterAnimationExecutor = enterAnimationExecutor
        self.revealSpeedStrategy = revealSpeedStrategy
        self.fragmentHeightMode = fragmentHeightMode
        self.baseCharsPerFrame = baseCharsPerFrame
        self.globalSpeedMultiplier = globalSpeedMultiplier
    }

    public func makeDriver() -> FragmentAnimationDriver {
        StreamAnimator(
            enterAnimationExecutor: enterAnimationExecutor,
            revealSpeedStrategy: revealSpeedStrategy,
            fragmentHeightMode: fragmentHeightMode,
            baseCharsPerFrame: baseCharsPerFrame,
            globalSpeedMultiplier: globalSpeedMultiplier
        )
    }
}

// MARK: - AnimationConfiguration

/// 动画配置
/// 注意：不使用单例，通过依赖注入
///
/// 使用方式:
/// ```swift
/// // 使用默认配置
/// let config = AnimationConfiguration.default
///
/// // 自定义配置
/// let config = AnimationConfiguration(
///     revealStrategyProvider: CustomRevealStrategyProvider(),
///     enterAnimationExecutor: SpringEnterAnimationExecutor(),
///     globalSpeedMultiplier: 1.2
/// )
///
/// // 注入到容器视图
/// let containerView = MarkdownContainerView(animationConfig: config)
/// ```
public struct AnimationConfiguration {
    
    // MARK: - Properties
    
    /// 进入动画执行器
    public var enterAnimationExecutor: EnterAnimationExecutor
    
    /// 全局速度倍率
    /// 影响所有动画的速度
    public var globalSpeedMultiplier: CGFloat
    
    /// 每帧基础字符数
    /// 实际字符数 = baseCharsPerFrame * globalSpeedMultiplier * contentConfig.speedMultiplier
    public var baseCharsPerFrame: Int

    /// Fragment 高度模式
    public var fragmentHeightMode: FragmentHeightMode

    /// 动画驱动提供者（协议）
    public var animationDriverProvider: FragmentAnimationDriverProvider

    /// Reveal 策略提供者（协议）
    public var revealStrategyProvider: TextRevealStrategyProvider

    /// 揭示速度策略
    public var revealSpeedStrategy: RevealSpeedStrategy

    // MARK: - Initialization

    public init(
        enterAnimationExecutor: EnterAnimationExecutor = DefaultEnterAnimationExecutor(),
        globalSpeedMultiplier: CGFloat = 1.0,
        baseCharsPerFrame: Int = 3,
        fragmentHeightMode: FragmentHeightMode = .fullContent,
        animationDriverProvider: FragmentAnimationDriverProvider = DefaultInstantDriverProvider(),
        revealStrategyProvider: TextRevealStrategyProvider = SubstringRevealStrategyProvider(),
        revealSpeedStrategy: RevealSpeedStrategy = LinearRevealSpeedStrategy()
    ) {
        self.enterAnimationExecutor = enterAnimationExecutor
        self.globalSpeedMultiplier = globalSpeedMultiplier
        self.baseCharsPerFrame = baseCharsPerFrame
        self.fragmentHeightMode = fragmentHeightMode
        self.animationDriverProvider = animationDriverProvider
        self.revealStrategyProvider = revealStrategyProvider
        self.revealSpeedStrategy = revealSpeedStrategy
    }
    
    // MARK: - Presets
    
    /// 默认配置
    public static let `default` = AnimationConfiguration()
    
    /// 快速配置（2倍速）
    public static let fast = AnimationConfiguration(
        globalSpeedMultiplier: 2.0
    )
    
    /// 无动画配置
    public static let noAnimation = AnimationConfiguration(
        globalSpeedMultiplier: .greatestFiniteMagnitude
    )

    /// 流式动画配置
    public static let animated = AnimationConfiguration(
        animationDriverProvider: StreamAnimatorProvider(
            fragmentHeightMode: .animationProgress
        ),
        revealSpeedStrategy: LinearRevealSpeedStrategy(
            baseCharsPerFrame: 3,
            globalSpeedMultiplier: 1.0
        )
    )
}
