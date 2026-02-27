//
//  StreamingAnimator.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

/// 流式动画调度器
///
/// 职责：在 Fragment 增量更新时，协调文字渐入、块展开、自定义动画。
/// 设计原则：
/// - 动画是可选的（传 nil 则无动画直接更新）
/// - 动画不阻塞数据更新（数据立即生效，动画只控制视觉呈现）
/// - 积压过多时自动加速（保证数据不延迟）
/// - 加速算法可注入（通过 speedStrategy 属性）
public final class StreamingAnimator {
    
    // MARK: - Properties
    
    /// 自定义 View 动画代理
    public weak var delegate: StreamingAnimationDelegate?
    
    /// 当前主题（用于获取动画配置）
    public var theme: MarkdownTheme = .default {
        didSet {
            // 主题变更时，如果没有自定义策略，则更新默认策略
            if !hasCustomSpeedStrategy {
                _speedStrategy = DefaultStreamingSpeedStrategy(theme: theme)
            }
            updateDisplayLinkFrameRate()
        }
    }
    
    /// 加速算法策略（可注入）
    ///
    /// 设置后将覆盖默认的阶梯式加速算法。
    /// 内置策略：
    /// - `DefaultStreamingSpeedStrategy`：阶梯式加速
    /// - `LinearSpeedStrategy`：线性加速
    /// - `ExponentialSpeedStrategy`：指数加速
    /// - `AdaptiveSpeedStrategy`：自适应加速
    /// - `FixedSpeedStrategy`：固定速度
    /// - `InstantSpeedStrategy`：即时显示
    public var speedStrategy: StreamingSpeedStrategy {
        get { _speedStrategy }
        set {
            _speedStrategy = newValue
            hasCustomSpeedStrategy = true
        }
    }
    
    private var _speedStrategy: StreamingSpeedStrategy = DefaultStreamingSpeedStrategy()
    private var hasCustomSpeedStrategy = false
    
    /// 动画队列（逐字渐入时，新增的文字排队等待显示）
    private var pendingTextReveal: [String: PendingTextItem] = [:]
    
    /// 待显示文本项
    private struct PendingTextItem {
        let label: UILabel
        let fullText: NSAttributedString
        var revealedLength: Int
    }
    
    /// CADisplayLink 驱动
    private var displayLink: CADisplayLink?
    
    /// 动画完成回调
    public var onAnimationComplete: (() -> Void)?
    
    /// 当前是否正在动画
    public private(set) var isAnimating: Bool = false
    
    // MARK: - Computed Properties (from theme)
    
    private var animationStyle: MarkdownTheme.AnimationStyle { theme.animation }
    private var streamingStyle: MarkdownTheme.StreamingAnimation { theme.animation.streaming }
    private var enterStyle: MarkdownTheme.EnterAnimation { theme.animation.enter }
    private var exitStyle: MarkdownTheme.ExitAnimation { theme.animation.exit }
    private var baseCharsPerFrame: Int { streamingStyle.baseCharsPerFrame }
    private var maxCharsPerFrame: Int { streamingStyle.maxCharsPerFrame }
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(theme: MarkdownTheme) {
        self.theme = theme
        self._speedStrategy = DefaultStreamingSpeedStrategy(theme: theme)
    }
    
    public init(theme: MarkdownTheme, speedStrategy: StreamingSpeedStrategy) {
        self.theme = theme
        self._speedStrategy = speedStrategy
        self.hasCustomSpeedStrategy = true
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    // MARK: - Fragment 动画入口
    
    /// 新增 Fragment 的动画
    public func animateInsert(view: UIView, fragment: RenderFragment, in container: UIView) {
        guard animationStyle.isEnabled else {
            // 动画禁用时直接设置内容
            applyContentDirectly(view: view, fragment: fragment)
            return
        }
        
        switch fragment {
        case let text as TextFragment:
            animateTextInsert(view: view, text: text, fragmentId: fragment.fragmentId)
            
        case let viewFrag as ViewFragment:
            animateViewInsert(view: view, fragment: viewFrag, in: container)
            
        default:
            break
        }
    }
    
    /// 更新 Fragment 的动画
    public func animateUpdate(
        view: UIView,
        from oldFrame: CGRect,
        to newFrame: CGRect,
        fragment: RenderFragment
    ) {
        if let text = fragment as? TextFragment {
            if let label = view as? UILabel {
                // 文本更新：检查是否有新增文字
                let oldLength = pendingTextReveal[fragment.fragmentId]?.revealedLength
                    ?? (label.attributedText?.length ?? 0)
                let newLength = text.attributedString.length
                
                if newLength > oldLength && streamingStyle.mode == .typewriter {
                    // 有新增文字 → 更新队列
                    pendingTextReveal[fragment.fragmentId] = PendingTextItem(
                        label: label,
                        fullText: text.attributedString,
                        revealedLength: oldLength
                    )
                    startDisplayLinkIfNeeded()
                } else {
                    label.attributedText = text.attributedString
                }
            } else if let textView = view as? UITextView {
                textView.attributedText = text.attributedString
            }
        }
        
        if oldFrame != newFrame {
            if animationStyle.isEnabled {
                UIView.animate(
                    withDuration: streamingStyle.textUpdateDuration,
                    delay: 0,
                    options: animationStyle.layoutCurve
                ) {
                    view.frame = newFrame
                }
            } else {
                view.frame = newFrame
            }
        }
    }
    
    /// 删除 Fragment 的动画
    public func animateRemove(
        view: UIView,
        fragment: RenderFragment,
        completion: @escaping () -> Void
    ) {
        // 从队列中移除
        pendingTextReveal.removeValue(forKey: fragment.fragmentId)
        
        guard animationStyle.isEnabled else {
            completion()
            return
        }
        
        if let delegate = delegate, let viewFrag = fragment as? ViewFragment {
            delegate.animateViewRemove(view, fragment: viewFrag, completion: completion)
        } else {
            performExitAnimation(view: view, completion: completion)
        }
    }
    
    // MARK: - Private Animation Methods
    
    private func animateTextInsert(view: UIView, text: TextFragment, fragmentId: String) {
        guard let label = view as? UILabel else {
            // 如果不是 UILabel，可能是 UITextView
            if let textView = view as? UITextView {
                handleTextViewInsert(textView: textView, text: text)
            }
            return
        }
        
        switch streamingStyle.mode {
        case .typewriter:
            // 先置空，加入队列
            label.attributedText = NSAttributedString(string: "")
            pendingTextReveal[fragmentId] = PendingTextItem(
                label: label,
                fullText: text.attributedString,
                revealedLength: 0
            )
            startDisplayLinkIfNeeded()
            
        case .fadeIn:
            view.alpha = 0
            label.attributedText = text.attributedString
            UIView.animate(withDuration: enterStyle.fadeInDuration) { view.alpha = 1 }
            
        case .none:
            label.attributedText = text.attributedString
        }
    }
    
    private func animateViewInsert(view: UIView, fragment: ViewFragment, in container: UIView) {
        // 优先走自定义动画
        if let delegate = delegate {
            delegate.animateViewInsert(view, fragment: fragment, in: container)
            return
        }
        
        // 根据进入动画类型执行
        let targetFrame = view.frame
        
        switch enterStyle.type {
        case .fadeIn:
            view.alpha = 0
            UIView.animate(
                withDuration: enterStyle.fadeInDuration,
                delay: enterStyle.delay,
                options: .curveEaseOut
            ) {
                view.alpha = 1
            }
            
        case .slideUp:
            view.frame = CGRect(
                x: targetFrame.minX,
                y: targetFrame.minY + enterStyle.slideUpOffset,
                width: targetFrame.width,
                height: targetFrame.height
            )
            view.alpha = 0
            UIView.animate(
                withDuration: enterStyle.fadeInDuration,
                delay: enterStyle.delay,
                options: .curveEaseOut
            ) {
                view.frame = targetFrame
                view.alpha = 1
            }
            
        case .spring:
            view.transform = CGAffineTransform(scaleX: enterStyle.scaleRatio, y: enterStyle.scaleRatio)
            view.alpha = 0
            UIView.animate(
                withDuration: enterStyle.fadeInDuration,
                delay: enterStyle.delay,
                usingSpringWithDamping: enterStyle.springDamping,
                initialSpringVelocity: enterStyle.springVelocity,
                options: []
            ) {
                view.transform = .identity
                view.alpha = 1
            }
            
        case .none:
            break
            
        case .combined(let types):
            // 组合动画：同时应用多种效果
            applyCombinedEnterAnimation(view: view, types: types, targetFrame: targetFrame)
        }
    }
    
    private func applyCombinedEnterAnimation(
        view: UIView,
        types: [MarkdownTheme.EnterAnimationType],
        targetFrame: CGRect
    ) {
        var initialTransform = CGAffineTransform.identity
        var needsPositionReset = false
        var positionOffset: CGFloat = 0
        
        for type in types {
            switch type {
            case .fadeIn:
                view.alpha = 0
            case .slideUp:
                needsPositionReset = true
                positionOffset = enterStyle.slideUpOffset
            case .spring:
                initialTransform = initialTransform.scaledBy(
                    x: enterStyle.scaleRatio,
                    y: enterStyle.scaleRatio
                )
            case .none, .combined:
                break
            }
        }
        
        view.transform = initialTransform
        if needsPositionReset {
            view.frame = CGRect(
                x: targetFrame.minX,
                y: targetFrame.minY + positionOffset,
                width: targetFrame.width,
                height: targetFrame.height
            )
        }
        
        UIView.animate(
            withDuration: enterStyle.fadeInDuration,
            delay: enterStyle.delay,
            usingSpringWithDamping: enterStyle.springDamping,
            initialSpringVelocity: enterStyle.springVelocity,
            options: []
        ) {
            view.transform = .identity
            view.alpha = 1
            if needsPositionReset {
                view.frame = targetFrame
            }
        }
    }
    
    private func performExitAnimation(view: UIView, completion: @escaping () -> Void) {
        switch exitStyle.type {
        case .fadeOut:
            UIView.animate(
                withDuration: exitStyle.fadeOutDuration,
                animations: { view.alpha = 0 },
                completion: { _ in completion() }
            )
            
        case .slideDown:
            UIView.animate(
                withDuration: exitStyle.fadeOutDuration,
                animations: {
                    view.frame.origin.y += self.exitStyle.slideDownOffset
                    view.alpha = 0
                },
                completion: { _ in completion() }
            )
            
        case .scaleDown:
            UIView.animate(
                withDuration: exitStyle.fadeOutDuration,
                animations: {
                    view.transform = CGAffineTransform(
                        scaleX: self.exitStyle.scaleRatio,
                        y: self.exitStyle.scaleRatio
                    )
                    view.alpha = 0
                },
                completion: { _ in completion() }
            )
            
        case .none:
            completion()
        }
    }
    
    private func applyContentDirectly(view: UIView, fragment: RenderFragment) {
        switch fragment {
        case let text as TextFragment:
            if let label = view as? UILabel {
                label.attributedText = text.attributedString
            } else if let textView = view as? UITextView {
                textView.attributedText = text.attributedString
            }
        default:
            break
        }
    }
    
    // MARK: - 逐字渐入 DisplayLink
    
    @objc private func displayLinkFire() {
        guard !pendingTextReveal.isEmpty else {
            stopDisplayLink()
            notifyAnimationComplete()
            return
        }
        
        isAnimating = true
        
        // 计算当前队列中待显示的总字符数
        let currentQueueSize = pendingTextReveal.values.reduce(0) {
            $0 + ($1.fullText.length - $1.revealedLength)
        }
        
        // 使用注入的策略计算当前帧的显示速度
        let calculatedChars = _speedStrategy.charsPerFrame(
            for: currentQueueSize,
            baseCharsPerFrame: baseCharsPerFrame
        )
        // 限制最大速度
        let currentCharsPerFrame = min(calculatedChars, maxCharsPerFrame)
        
        var completedFragments: [String] = []
        
        for (fragmentId, var item) in pendingTextReveal {
            let newLength = min(item.revealedLength + currentCharsPerFrame, item.fullText.length)
            let revealed = item.fullText.attributedSubstring(from: NSRange(location: 0, length: newLength))
            item.label.attributedText = revealed
            
            item.revealedLength = newLength
            pendingTextReveal[fragmentId] = item
            
            if newLength >= item.fullText.length {
                completedFragments.append(fragmentId)
            }
        }
        
        // 移除已完成的
        for fragmentId in completedFragments {
            pendingTextReveal.removeValue(forKey: fragmentId)
        }
    }
    
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        isAnimating = true
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFire))
        displayLink?.preferredFramesPerSecond = streamingStyle.frameRateMode.preferredFramesPerSecond
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        isAnimating = false
    }
    
    private func updateDisplayLinkFrameRate() {
        displayLink?.preferredFramesPerSecond = streamingStyle.frameRateMode.preferredFramesPerSecond
    }
    
    private func notifyAnimationComplete() {
        guard streamingStyle.completionDelay > 0 else {
            onAnimationComplete?()
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + streamingStyle.completionDelay) { [weak self] in
            self?.onAnimationComplete?()
        }
    }
    
    // MARK: - 控制方法
    
    /// 用户主动快进（如点击"快速查看"按钮）
    public func fastForward() {
        guard !pendingTextReveal.isEmpty else { return }
        
        if streamingStyle.fastForwardAnimated {
            // 带动画的快进
            let duration = streamingStyle.fastForwardDuration
            
            for (_, item) in pendingTextReveal {
                // 使用淡入过渡
                UIView.transition(
                    with: item.label,
                    duration: duration,
                    options: .transitionCrossDissolve
                ) {
                    item.label.attributedText = item.fullText
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.pendingTextReveal.removeAll()
                self?.stopDisplayLink()
                self?.notifyAnimationComplete()
            }
        } else {
            // 无动画快进
            for (_, item) in pendingTextReveal {
                item.label.attributedText = item.fullText
            }
            pendingTextReveal.removeAll()
            stopDisplayLink()
            notifyAnimationComplete()
        }
    }
    
    /// 流式结束 → flush 所有待显示文字 + 停止 displayLink
    public func finish() {
        for (_, item) in pendingTextReveal {
            item.label.attributedText = item.fullText
        }
        pendingTextReveal.removeAll()
        stopDisplayLink()
        _speedStrategy.reset()
        notifyAnimationComplete()
    }
    
    /// 重置
    public func reset() {
        pendingTextReveal.removeAll()
        stopDisplayLink()
        _speedStrategy.reset()
        isAnimating = false
    }
    
    /// 暂停动画
    public func pause() {
        displayLink?.isPaused = true
    }
    
    /// 恢复动画
    public func resume() {
        displayLink?.isPaused = false
    }
    
    /// 设置动画速度倍率（临时调整）
    /// - Parameter multiplier: 速度倍率，1.0 为正常速度
    public func setSpeedMultiplier(_ multiplier: Double) {
        // 通过替换策略实现
        let currentBase = baseCharsPerFrame
        let adjustedBase = max(1, Int(Double(currentBase) * multiplier))
        
        // 创建临时固定速度策略
        _speedStrategy = FixedSpeedStrategy(fixedCharsPerFrame: adjustedBase)
        hasCustomSpeedStrategy = true
    }
    
    /// 恢复默认速度策略
    public func resetSpeedStrategy() {
        _speedStrategy = DefaultStreamingSpeedStrategy(theme: theme)
        hasCustomSpeedStrategy = false
    }
    
    // MARK: - 私有方法
    
    private func handleTextViewInsert(textView: UITextView, text: TextFragment) {
        switch streamingStyle.mode {
        case .typewriter:
            // UITextView 暂不支持逐字渐入，使用淡入代替
            textView.alpha = 0
            textView.attributedText = text.attributedString
            UIView.animate(withDuration: enterStyle.fadeInDuration) { textView.alpha = 1 }
            
        case .fadeIn:
            textView.alpha = 0
            textView.attributedText = text.attributedString
            UIView.animate(withDuration: enterStyle.fadeInDuration) { textView.alpha = 1 }
            
        case .none:
            textView.attributedText = text.attributedString
        }
    }
    
    // MARK: - 统计信息
    
    /// 当前队列中待显示的字符数
    public var pendingCharacterCount: Int {
        pendingTextReveal.values.reduce(0) {
            $0 + ($1.fullText.length - $1.revealedLength)
        }
    }
    
    /// 当前队列中的片段数
    public var pendingFragmentCount: Int {
        pendingTextReveal.count
    }
}

// MARK: - 流式动画代理

/// 流式动画代理 — 自定义 View 的进场/更新/退场动画
///
/// 宿主 App 实现此协议，为特定的 ViewFragment 提供自定义动画。
/// 未实现时 StreamingAnimator 使用默认动画（高度展开/淡出）。
public protocol StreamingAnimationDelegate: AnyObject {
    
    /// 新增 ViewFragment 的进场动画
    /// - Parameters:
    ///   - view: 已创建并设置好 frame 的 View
    ///   - fragment: 对应的 ViewFragment（可通过 reuseIdentifier 判断类型）
    ///   - container: 父容器
    func animateViewInsert(_ view: UIView, fragment: ViewFragment, in container: UIView)
    
    /// ViewFragment 被移除的退场动画
    /// - Parameters:
    ///   - view: 即将被移除的 View
    ///   - fragment: 对应的 ViewFragment
    ///   - completion: 动画完成后必须调用（触发 View 回收）
    func animateViewRemove(_ view: UIView, fragment: ViewFragment, completion: @escaping () -> Void)
}
