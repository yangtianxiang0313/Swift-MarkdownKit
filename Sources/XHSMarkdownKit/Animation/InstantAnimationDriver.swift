//
//  InstantAnimationDriver.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - InstantAnimationDriver

/// 瞬时动画驱动
/// applyDiff 内一次性创建全部 View、reveal 完整内容、不启动 tick
public final class InstantAnimationDriver: FragmentAnimationDriver {
    public weak var delegate: FragmentAnimationDriverDelegate?
    public var theme: MarkdownTheme = .default

    public init() {}

    public func applyDiff(changes: [FragmentChange], fragments: [RenderFragment], frames: [String: CGRect]) {
        for change in changes {
            if case .insert(let fragment, let index) = change {
                if let view = delegate?.fragmentAnimationDriver(self, createAndAddViewFor: fragment.fragmentId) {
                    view.alpha = 1
                    if let streamable = view as? StreamableContent {
                        streamable.reveal(upTo: streamable.totalLength)
                    }
                    delegate?.fragmentAnimationDriver(self, didAddFragmentAt: index)
                }
            }
        }
    }

    public func handleUpdate(fragmentId: String, updateResult: ContentUpdateResult) {}

    public func handleDelete(fragmentId: String) {}

    public func skipToEnd() {}

    public func reset() {}
}
