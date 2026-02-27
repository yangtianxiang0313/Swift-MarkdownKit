//
//  StreamingSpeedStrategy.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-26.
//

import Foundation

// MARK: - SpeedStrategyConstants

/// 速度策略相关常量
public enum SpeedStrategyConstants {
    /// 轻微积压时的字符增量
    public static let lightBacklogIncrement = 1
    /// 自适应策略趋势计算窗口大小
    public static let trendWindowSize = 3
}

// MARK: - StreamingSpeedStrategy Protocol

/// 流式动画速度策略协议
///
/// 使用场景：
/// - 默认阶梯式加速算法可能不适合所有场景
/// - 某些场景需要平滑加速、指数加速或自定义算法
/// - 通过协议化，宿主 App 可注入自己的加速策略
///
/// 示例：
/// ```swift
/// // 使用内置策略
/// animator.speedStrategy = DefaultStreamingSpeedStrategy(theme: theme)
///
/// // 使用线性加速策略
/// animator.speedStrategy = LinearSpeedStrategy(minChars: 1, maxChars: 10)
///
/// // 自定义策略
/// animator.speedStrategy = MyCustomSpeedStrategy()
/// ```
public protocol StreamingSpeedStrategy {
    
    /// 根据当前积压字符数计算每帧应显示的字符数
    ///
    /// - Parameters:
    ///   - queueSize: 当前队列中待显示的总字符数
    ///   - baseCharsPerFrame: 基础速度（无积压时的字符数/帧）
    /// - Returns: 当前帧应显示的字符数
    func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int
    
    /// 重置策略状态（可选）
    /// 当流式渲染结束或重新开始时调用
    func reset()
}

// MARK: - Default Implementation

public extension StreamingSpeedStrategy {
    func reset() {
        // 默认无状态，不需要重置
    }
}

// MARK: - DefaultStreamingSpeedStrategy

/// 默认阶梯式加速策略
///
/// 基于积压字符数分阶段加速：
/// - 0~level1: 基础速度
/// - level1~level2: 1.5 倍速
/// - level2~level3: 2 倍速
/// - level3~level4: 3 倍速
/// - level4+: 4 倍速
public struct DefaultStreamingSpeedStrategy: StreamingSpeedStrategy {
    
    public let thresholds: MarkdownTheme.StreamingThresholds
    
    public init(thresholds: MarkdownTheme.StreamingThresholds = .default) {
        self.thresholds = thresholds
    }
    
    public init(theme: MarkdownTheme) {
        self.thresholds = theme.animation.streaming.thresholds
    }
    
    public func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int {
        switch queueSize {
        case 0..<thresholds.level1:
            // 无积压：基础速度
            return baseCharsPerFrame
        case thresholds.level1..<thresholds.level2:
            // 轻微积压
            return baseCharsPerFrame + SpeedStrategyConstants.lightBacklogIncrement
        case thresholds.level2..<thresholds.level3:
            // 中等积压：2 倍速
            return baseCharsPerFrame * 2
        case thresholds.level3..<thresholds.level4:
            // 严重积压：3 倍速
            return baseCharsPerFrame * 3
        default:
            // 极端积压：4 倍速
            return baseCharsPerFrame * 4
        }
    }
}

// MARK: - LinearSpeedStrategy

/// 线性加速策略
///
/// 根据积压字符数线性增加速度，适合需要平滑加速的场景
public struct LinearSpeedStrategy: StreamingSpeedStrategy {
    
    /// 最小字符数/帧
    public let minCharsPerFrame: Int
    /// 最大字符数/帧
    public let maxCharsPerFrame: Int
    /// 达到最大速度的积压阈值
    public let maxThreshold: Int
    
    public static let defaultMinChars = 1
    public static let defaultMaxChars = 8
    public static let defaultMaxThreshold = 200
    
    public init(
        minCharsPerFrame: Int = defaultMinChars,
        maxCharsPerFrame: Int = defaultMaxChars,
        maxThreshold: Int = defaultMaxThreshold
    ) {
        self.minCharsPerFrame = minCharsPerFrame
        self.maxCharsPerFrame = maxCharsPerFrame
        self.maxThreshold = maxThreshold
    }
    
    public func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int {
        guard queueSize > 0 else { return minCharsPerFrame }
        guard queueSize < maxThreshold else { return maxCharsPerFrame }
        
        // 线性插值
        let ratio = Double(queueSize) / Double(maxThreshold)
        let range = maxCharsPerFrame - minCharsPerFrame
        return minCharsPerFrame + Int(Double(range) * ratio)
    }
}

// MARK: - ExponentialSpeedStrategy

/// 指数加速策略
///
/// 积压越多，加速越快（指数增长），适合需要快速追赶的场景
public struct ExponentialSpeedStrategy: StreamingSpeedStrategy {
    
    public static let defaultBase = 1.02
    public static let defaultScaleFactor = 1.0
    public static let defaultMaxCharsPerFrame = 20
    public static let scaleDivisor: Double = 100.0
    
    /// 指数底数（1.0~2.0）
    public let base: Double
    /// 缩放因子（控制敏感度）
    public let scaleFactor: Double
    /// 最大字符数/帧
    public let maxCharsPerFrame: Int
    
    public init(
        base: Double = defaultBase,
        scaleFactor: Double = defaultScaleFactor,
        maxCharsPerFrame: Int = defaultMaxCharsPerFrame
    ) {
        self.base = max(1.0, min(base, 2.0))
        self.scaleFactor = scaleFactor
        self.maxCharsPerFrame = maxCharsPerFrame
    }
    
    public func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int {
        guard queueSize > 0 else { return baseCharsPerFrame }
        
        // 指数增长: base^(queueSize * scaleFactor / scaleDivisor)
        let exponent = Double(queueSize) * scaleFactor / Self.scaleDivisor
        let multiplier = pow(base, exponent)
        let result = Int(Double(baseCharsPerFrame) * multiplier)
        
        return min(result, maxCharsPerFrame)
    }
}

// MARK: - AdaptiveSpeedStrategy

/// 自适应加速策略
///
/// 根据历史积压趋势动态调整速度：
/// - 积压持续增加 → 更激进加速
/// - 积压持续减少 → 逐渐减速
/// - 积压稳定 → 保持当前速度
public final class AdaptiveSpeedStrategy: StreamingSpeedStrategy {
    
    /// 历史记录窗口大小
    public let historyWindowSize: Int
    /// 最大加速倍数
    public let maxMultiplier: Double
    /// 最小加速倍数
    public let minMultiplier: Double
    /// 趋势敏感度（0~1）
    public let trendSensitivity: Double
    
    public static let defaultHistoryWindowSize = 10
    public static let defaultMaxMultiplier = 5.0
    public static let defaultMinMultiplier = 1.0
    public static let defaultTrendSensitivity = 0.3
    
    private var queueHistory: [Int] = []
    private var currentMultiplier: Double = 1.0
    
    public init(
        historyWindowSize: Int = defaultHistoryWindowSize,
        maxMultiplier: Double = defaultMaxMultiplier,
        minMultiplier: Double = defaultMinMultiplier,
        trendSensitivity: Double = defaultTrendSensitivity
    ) {
        self.historyWindowSize = historyWindowSize
        self.maxMultiplier = maxMultiplier
        self.minMultiplier = minMultiplier
        self.trendSensitivity = trendSensitivity
    }
    
    public func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int {
        // 记录历史
        queueHistory.append(queueSize)
        if queueHistory.count > historyWindowSize {
            queueHistory.removeFirst()
        }
        
        // 计算趋势
        let trend = calculateTrend()
        
        // 调整倍数
        if trend > 0 {
            // 积压增加：加速
            currentMultiplier = min(currentMultiplier + trendSensitivity * trend, maxMultiplier)
        } else if trend < 0 {
            // 积压减少：减速
            currentMultiplier = max(currentMultiplier + trendSensitivity * trend, minMultiplier)
        }
        
        return Int(Double(baseCharsPerFrame) * currentMultiplier)
    }
    
    public func reset() {
        queueHistory.removeAll()
        currentMultiplier = 1.0
    }
    
    /// 计算积压趋势（-1 到 1）
    private func calculateTrend() -> Double {
        guard queueHistory.count >= 2 else { return 0 }
        
        let recent = queueHistory.suffix(min(SpeedStrategyConstants.trendWindowSize, queueHistory.count))
        let older = queueHistory.prefix(max(1, queueHistory.count - SpeedStrategyConstants.trendWindowSize))
        
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let olderAvg = Double(older.reduce(0, +)) / Double(older.count)
        
        guard olderAvg > 0 else { return recentAvg > 0 ? 1.0 : 0 }
        
        let change = (recentAvg - olderAvg) / olderAvg
        return max(-1.0, min(change, 1.0))
    }
}

// MARK: - FixedSpeedStrategy

/// 固定速度策略
///
/// 无论积压多少，始终以固定速度显示，适合需要稳定节奏的场景
public struct FixedSpeedStrategy: StreamingSpeedStrategy {
    
    public static let defaultCharsPerFrame = 2
    
    /// 固定的字符数/帧
    public let fixedCharsPerFrame: Int
    
    public init(fixedCharsPerFrame: Int = defaultCharsPerFrame) {
        self.fixedCharsPerFrame = fixedCharsPerFrame
    }
    
    public func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int {
        return fixedCharsPerFrame
    }
}

// MARK: - InstantSpeedStrategy

/// 即时显示策略
///
/// 不做动画，立即显示所有文字
public struct InstantSpeedStrategy: StreamingSpeedStrategy {
    
    public static let unlimitedChars = Int.max
    
    public init() {}
    
    public func charsPerFrame(for queueSize: Int, baseCharsPerFrame: Int) -> Int {
        // 返回一个很大的数，确保一帧内全部显示
        return Self.unlimitedChars
    }
}
