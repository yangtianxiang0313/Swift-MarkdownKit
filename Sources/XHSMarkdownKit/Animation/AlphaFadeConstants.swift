//
//  AlphaFadeConstants.swift
//  XHSMarkdownKit
//

import Foundation

/// Alpha 渐入策略相关常量
public enum AlphaFadeConstants {
    /// 最小 alpha 值
    public static let minAlpha: CGFloat = 0
    /// 最大 alpha 值
    public static let maxAlpha: CGFloat = 1
    /// 默认渐入时长
    public static let defaultFadeDuration: CFTimeInterval = 0.5
    /// 完成阈值（alpha 达到此值视为完成）
    public static let completionThreshold: CGFloat = 1.0
    /// 判断动画完成的余量时间（秒）
    public static let completionTolerance: CFTimeInterval = 1.0
}
