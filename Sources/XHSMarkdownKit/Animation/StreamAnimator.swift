//
//  StreamAnimator.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - StreamAnimator

/// 流式动画驱动
/// tick 懒创建 + enter + reveal
public final class StreamAnimator: FragmentAnimationDriver {
    public weak var delegate: FragmentAnimationDriverDelegate?
    public var theme: MarkdownTheme = .default

    private var fragmentOrder: [String] = []
    private var targetProgress: [String: Int] = [:]
    private var currentPlayingIndex: Int = 0
    private var lastAddedIndex: Int = -1
    private var views: [String: WeakRef<UIView>] = [:]
    private var enteredViews: Set<String> = []
    private var isPaused: Bool = false
    private var displayLink: CADisplayLink?

    private let enterAnimationExecutor: EnterAnimationExecutor
    private let revealSpeedStrategy: RevealSpeedStrategy
    private let fragmentHeightMode: FragmentHeightMode
    private let baseCharsPerFrame: Int
    private let globalSpeedMultiplier: CGFloat

    public var onAnimationComplete: (() -> Void)?

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

    public func applyDiff(changes: [FragmentChange], fragments: [RenderFragment], frames: [String: CGRect]) {
        fragmentOrder = fragments.compactMap { $0 as? FragmentViewFactory }.map { $0.fragmentId }
        for fragment in fragments {
            if let vf = fragment as? FragmentViewFactory {
                targetProgress[vf.fragmentId] = targetLengthForFragment(fragment)
            }
        }
        for change in changes {
            switch change {
            case .insert(let fragment, _):
                targetProgress[fragment.fragmentId] = targetForFragment(fragment)
            case .update(_, let new, _):
                targetProgress[new.fragmentId] = targetForFragment(new)
            case .delete(let fragment, _):
                targetProgress.removeValue(forKey: fragment.fragmentId)
                views.removeValue(forKey: fragment.fragmentId)
                enteredViews.remove(fragment.fragmentId)
                if let idx = fragmentOrder.firstIndex(of: fragment.fragmentId) {
                    fragmentOrder.remove(at: idx)
                    if idx < currentPlayingIndex { currentPlayingIndex = max(0, currentPlayingIndex - 1) }
                }
            }
        }
        startDisplayLinkIfNeeded()
    }

    private func targetLengthForFragment(_ fragment: RenderFragment) -> Int {
        if let textFrag = fragment as? TextFragment {
            return textFrag.attributedString.length
        }
        if let viewFrag = fragment as? ViewFragment {
            if let codeContent = viewFrag.content as? CodeBlockContent {
                return (codeContent.code as NSString).length
            }
            return 0  // Table/Image 等：displayedLength=totalLength 一次性显示
        }
        return 0
    }

    private func targetForFragment(_ fragment: RenderFragment) -> Int {
        targetLengthForFragment(fragment)
    }

    public func handleUpdate(fragmentId: String, updateResult: ContentUpdateResult) {
        switch updateResult.type {
        case .unchanged:
            break
        case .append, .truncated:
            targetProgress[fragmentId] = updateResult.currentLength
        case .modified(let prefixLen):
            targetProgress[fragmentId] = updateResult.currentLength
            if let view = views[fragmentId]?.value as? StreamableContent, view.displayedLength > prefixLen {
                view.reveal(upTo: prefixLen)
            }
        }
        startDisplayLinkIfNeeded()
    }

    public func handleDelete(fragmentId: String) {
        views.removeValue(forKey: fragmentId)
        targetProgress.removeValue(forKey: fragmentId)
        enteredViews.remove(fragmentId)
        if let idx = fragmentOrder.firstIndex(of: fragmentId) {
            fragmentOrder.remove(at: idx)
            if idx < currentPlayingIndex { currentPlayingIndex = max(0, currentPlayingIndex - 1) }
        }
    }

    public func skipToEnd() {
        for fragmentId in fragmentOrder {
            if let view = views[fragmentId]?.value as? StreamableContent,
               let target = targetProgress[fragmentId] {
                view.reveal(upTo: target)
                if !enteredViews.contains(fragmentId) {
                    enteredViews.insert(fragmentId)
                    view.alpha = 1
                }
            }
        }
        currentPlayingIndex = fragmentOrder.count
        isPaused = false
        stopDisplayLink()
        onAnimationComplete?()
    }

    public func reset() {
        stopDisplayLink()
        fragmentOrder.removeAll()
        targetProgress.removeAll()
        views.removeAll()
        enteredViews.removeAll()
        currentPlayingIndex = 0
        lastAddedIndex = -1
        isPaused = false
    }

    @objc private func tick() {
        guard !isPaused else { return }

        guard currentPlayingIndex < fragmentOrder.count else {
            stopDisplayLink()
            onAnimationComplete?()
            return
        }

        let fragmentId = fragmentOrder[currentPlayingIndex]
        var view = views[fragmentId]?.value

        if view == nil {
            view = delegate?.fragmentAnimationDriver(self, createAndAddViewFor: fragmentId)
            if let v = view {
                views[fragmentId] = WeakRef(v)
                lastAddedIndex = currentPlayingIndex
                delegate?.fragmentAnimationDriver(self, didAddFragmentAt: currentPlayingIndex)
                v.alpha = 0
            } else {
                currentPlayingIndex += 1
                return
            }
        }

        guard let v = view else {
            currentPlayingIndex += 1
            return
        }

        guard let streamable = v as? StreamableContent else {
            currentPlayingIndex += 1
            return
        }

        let target = targetProgress[fragmentId] ?? streamable.totalLength

        if !enteredViews.contains(fragmentId) {
            enteredViews.insert(fragmentId)
            if let config = streamable.enterAnimationConfig, config.type != .none {
                if config.blocksSubsequent {
                    isPaused = true
                    enterAnimationExecutor.execute(v, config: config, theme: theme) { [weak self] in
                        self?.isPaused = false
                    }
                    return
                } else {
                    enterAnimationExecutor.execute(v, config: config, theme: theme, completion: {})
                }
            } else {
                v.alpha = 1
            }
        }

        let current = streamable.displayedLength
        if current < target {
            let step = revealSpeedStrategy.charsPerFrame(
                currentLength: current,
                targetLength: target,
                fragmentId: fragmentId,
                contentConfig: nil
            )
            let newLen = min(current + step, target)
            streamable.reveal(upTo: newLen)

            if fragmentHeightMode == .animationProgress {
                delegate?.fragmentAnimationDriver(self, contentHeightNeedsUpdateFor: fragmentId, displayedLength: newLen)
            }
        }

        if streamable.displayedLength >= (targetProgress[fragmentId] ?? 0) {
            currentPlayingIndex += 1
        }
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

// MARK: - WeakRef

private final class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
