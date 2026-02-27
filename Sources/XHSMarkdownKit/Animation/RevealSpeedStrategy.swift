//
//  RevealSpeedStrategy.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - RevealSpeedStrategy

/// 揭示速度策略协议
public protocol RevealSpeedStrategy {
    func charsPerFrame(
        currentLength: Int,
        targetLength: Int,
        fragmentId: String,
        contentConfig: ContentAnimationConfig?
    ) -> Int
}

// MARK: - LinearRevealSpeedStrategy

/// 线性速度策略
public struct LinearRevealSpeedStrategy: RevealSpeedStrategy {
    public let baseCharsPerFrame: Int
    public let globalSpeedMultiplier: CGFloat

    public init(baseCharsPerFrame: Int = 3, globalSpeedMultiplier: CGFloat = 1.0) {
        self.baseCharsPerFrame = baseCharsPerFrame
        self.globalSpeedMultiplier = globalSpeedMultiplier
    }

    public func charsPerFrame(
        currentLength: Int,
        targetLength: Int,
        fragmentId: String,
        contentConfig: ContentAnimationConfig?
    ) -> Int {
        let multiplier = contentConfig?.speedMultiplier ?? 1.0
        return max(1, Int(ceil(CGFloat(baseCharsPerFrame) * globalSpeedMultiplier * multiplier)))
    }
}
