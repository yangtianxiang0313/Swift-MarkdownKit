//
//  FragmentAnimationDriver.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - FragmentAnimationDriverDelegate

/// 动画驱动委托
public protocol FragmentAnimationDriverDelegate: AnyObject {
    func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, createAndAddViewFor fragmentId: String) -> UIView?
    func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, didAddFragmentAt index: Int)
    /// heightMode == .animationProgress 时，tick 中 displayedLength 变化后调用
    func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, contentHeightNeedsUpdateFor fragmentId: String, displayedLength: Int)
}

// MARK: - FragmentAnimationDriver

/// 动画驱动协议
public protocol FragmentAnimationDriver: AnyObject {
    var delegate: FragmentAnimationDriverDelegate? { get set }
    var theme: MarkdownTheme { get set }
    func applyDiff(changes: [FragmentChange], fragments: [RenderFragment], frames: [String: CGRect])
    func handleUpdate(fragmentId: String, updateResult: ContentUpdateResult)
    func handleDelete(fragmentId: String)
    func skipToEnd()
    func reset()
}
