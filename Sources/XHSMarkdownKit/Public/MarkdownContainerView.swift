//
//  MarkdownContainerView.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

// MARK: - MarkdownContainerView

/// Markdown 内容的布局容器
///
/// 采用手动 frame 布局（非 Auto Layout），性能最优。
/// Markdown 的块级结构天然是线性的，只需从上到下累加 y 偏移即可。
///
/// 使用方式:
/// ```swift
/// // 创建容器（使用依赖注入，非单例）
/// let engine = MarkdownRenderEngine.makeDefault(theme: .dark)
/// let container = MarkdownContainerView(engine: engine)
///
/// // 渲染内容
/// container.render("# Hello\n\nWorld")
///
/// // 流式渲染
/// container.appendText("New content...")
/// ```
public final class MarkdownContainerView: UIView {
    
    // MARK: - Dependencies
    
    /// 渲染引擎
    public let engine: MarkdownRenderEngine
    
    /// 动画配置
    public let animationConfig: AnimationConfiguration
    
    /// Fragment 外部状态存储（可选，用于折叠、复制等跨 render 状态）
    public let stateStore: FragmentStateStore
    
    // MARK: - State
    
    /// 当前渲染结果
    public private(set) var renderResult: MarkdownRenderResult?
    
    /// 已创建的子 View 缓存（key: fragmentId）
    public private(set) var fragmentViews: [String: UIView] = [:]
    
    /// 各 Fragment 的 frame（预计算结果）
    private var fragmentFrames: [String: CGRect] = [:]
    
    /// View 复用池（key: reuseIdentifier）
    private var reusePool: [String: [UIView]] = [:]
    
    /// 内容总高度（预计算）
    public private(set) var contentHeight: CGFloat = 0
    
    /// 动画驱动（由 config 创建）
    private lazy var animationDriver: FragmentAnimationDriver = {
        let driver = animationConfig.animationDriverProvider.makeDriver()
        driver.delegate = self
        driver.theme = theme
        return driver
    }()
    
    /// 流式文本缓冲
    private var streamingBuffer: String = ""
    
    /// 是否处于流式模式
    private var isStreaming: Bool = false
    
    // MARK: - Computed Properties (from theme)
    
    private var theme: MarkdownTheme { engine.theme }
    private var spacingStyle: MarkdownTheme.SpacingStyle { theme.spacing }
    private var animationStyle: MarkdownTheme.AnimationStyle { theme.animation }
    private var blockQuoteStyle: MarkdownTheme.BlockQuoteStyle { theme.blockQuote }
    private var codeStyle: MarkdownTheme.CodeStyle { theme.code }
    
    // MARK: - Callbacks
    
    /// 高度变化回调
    public var onContentHeightChanged: ((CGFloat) -> Void)?
    
    /// 动画完成回调
    public var onAnimationComplete: (() -> Void)? {
        didSet {
            (animationDriver as? StreamAnimator)?.onAnimationComplete = onAnimationComplete
        }
    }
    
    // MARK: - Configuration
    
    /// 片段间距（设为 0 时使用主题的 paragraphSpacing）
    public var fragmentSpacing: CGFloat = 0
    
    /// 获取实际使用的片段间距
    private var effectiveSpacing: CGFloat {
        fragmentSpacing > 0 ? fragmentSpacing : spacingStyle.paragraph
    }
    
    /// 可用宽度
    public var maxWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            if maxWidth != oldValue {
                setNeedsLayout()
            }
        }
    }
    
    // MARK: - Initialization
    
    /// 完整初始化
    public init(
        engine: MarkdownRenderEngine? = nil,
        animationConfig: AnimationConfiguration = .default,
        stateStore: FragmentStateStore? = nil,
        frame: CGRect = .zero
    ) {
        let store = stateStore ?? FragmentStateStore()
        self.engine = engine ?? .makeDefault(stateStore: store)
        self.animationConfig = animationConfig
        self.stateStore = store
        super.init(frame: frame)
        setup(stateStore: store)
    }
    
    /// 便捷初始化（使用主题）
    public convenience init(theme: MarkdownTheme) {
        let store = FragmentStateStore()
        self.init(engine: .makeDefault(theme: theme, stateStore: store), stateStore: store)
    }
    
    required init?(coder: NSCoder) {
        let store = FragmentStateStore()
        self.engine = .makeDefault(stateStore: store)
        self.animationConfig = .default
        self.stateStore = store
        super.init(coder: coder)
        setup(stateStore: store)
    }
    
    private func setup(stateStore: FragmentStateStore? = nil) {
        clipsToBounds = true
        let store = stateStore ?? self.stateStore
        store.onStateChange = { [weak self] fragmentId in
            self?.handleStateChange(fragmentId: fragmentId)
        }
    }
    
    private func handleStateChange(fragmentId: String) {
        let text = isStreaming ? streamingBuffer : (renderResult?.sourceText ?? "")
        guard !text.isEmpty else { return }
        let result = engine.render(text, mode: isStreaming ? .streaming : .normal, maxWidth: effectiveRenderWidth)
        applyDiff(result, oldFragments: renderResult?.fragments ?? [])
    }

    /// 渲染时使用的有效宽度（用于 Fragment 高度计算，必须有限值才能正确换行）
    private var effectiveRenderWidth: CGFloat {
        let w = maxWidth == .greatestFiniteMagnitude ? bounds.width : maxWidth
        return w > 0 ? w : 375
    }
    
    deinit {
        animationDriver.reset()
    }
    
    // MARK: - Public API: 非流式渲染
    
    /// 渲染 Markdown 文本（非流式，无动画）
    public func render(_ text: String) {
        isStreaming = false
        streamingBuffer = ""
        
        let result = engine.render(text, mode: .normal, maxWidth: effectiveRenderWidth)
        apply(result)
    }
    
    /// 应用渲染结果（非流式）
    public func apply(_ result: MarkdownRenderResult) {
        applyDiff(result, oldFragments: renderResult?.fragments ?? [])
    }
    
    // MARK: - Public API: 流式渲染
    
    /// 开始流式渲染
    public func startStreaming() {
        isStreaming = true
        streamingBuffer = ""
        clear()
    }
    
    /// 追加流式文本
    public func appendText(_ text: String) {
        guard isStreaming else {
            // 非流式模式，直接渲染
            render(text)
            return
        }
        
        streamingBuffer += text
        
        let oldResult = renderResult
        let newResult = engine.render(streamingBuffer, mode: .streaming, maxWidth: effectiveRenderWidth)
        
        applyDiff(newResult, oldFragments: oldResult?.fragments ?? [])
    }
    
    /// 结束流式渲染
    public func endStreaming() {
        isStreaming = false
        
        // 最终渲染（normal 模式，不做预闭合）
        if !streamingBuffer.isEmpty {
            let finalResult = engine.render(streamingBuffer, mode: .normal, maxWidth: effectiveRenderWidth)
            applyDiff(finalResult, oldFragments: renderResult?.fragments ?? [])
        }
    }
    
    /// 快进动画
    public func skipAnimation() {
        animationDriver.skipToEnd()
    }
    
    // MARK: - Private: 应用 Diff

    private func applyDiff(_ newResult: MarkdownRenderResult, oldFragments: [RenderFragment]) {
        let changes = StreamingFragmentDiffer.diff(old: oldFragments, new: newResult.fragments)
        
        self.renderResult = newResult
        calculateFrames(for: newResult.fragments)

        for change in changes {
            switch change {
            case .insert:
                break
            case .update(let old, let new, _):
                handleUpdate(oldFragment: old, newFragment: new)
            case .delete(let fragment, _):
                handleDelete(fragment: fragment)
            }
        }

        animationDriver.theme = theme
        animationDriver.applyDiff(changes: changes, fragments: newResult.fragments, frames: fragmentFrames)
        updateViewPositions()
        stateStore.gc(existingIds: Set(newResult.fragments.map { $0.fragmentId }))
    }

    private func handleUpdate(oldFragment: RenderFragment, newFragment: RenderFragment) {
        guard let view = fragmentViews[oldFragment.fragmentId] else { return }

        if oldFragment.fragmentId != newFragment.fragmentId {
            fragmentViews.removeValue(forKey: oldFragment.fragmentId)
            fragmentViews[newFragment.fragmentId] = view
        }

        var updateResult: ContentUpdateResult = .zero
        if let streamable = view as? StreamableContent {
            if let textFrag = newFragment as? TextFragment {
                updateResult = streamable.updateContent(textFrag.attributedString)
            } else if let viewFrag = newFragment as? ViewFragment {
                updateResult = streamable.updateContent(viewFrag.content)
            }
        } else {
            configureFragmentView(view, with: newFragment)
        }

        if let newFrame = fragmentFrames[newFragment.fragmentId] {
            UIView.animate(withDuration: animationStyle.layoutDuration) {
                view.frame = newFrame
            }
        }

        animationDriver.handleUpdate(fragmentId: newFragment.fragmentId, updateResult: updateResult)

        // Instant 驱动：update 后需立即 reveal，否则 updateContent 只更新策略内部状态，view 仍显示旧内容
        if let streamable = view as? StreamableContent,
           animationDriver is InstantAnimationDriver {
            streamable.reveal(upTo: updateResult.currentLength)
        }
    }

    private func handleDelete(fragment: RenderFragment) {
        guard let view = fragmentViews.removeValue(forKey: fragment.fragmentId) else { return }
        let reuseId = (fragment as? FragmentViewFactory)?.reuseIdentifier.rawValue ?? ReuseIdentifier.textView.rawValue

        animationDriver.handleDelete(fragmentId: fragment.fragmentId)
        UIView.animate(withDuration: animationStyle.layoutDuration, animations: {
            view.alpha = AnimationConstants.initialAlpha
        }, completion: { _ in
            view.removeFromSuperview()
            self.recycleView(view, reuseId: reuseId)
        })
    }
    
    // MARK: - Private: Frame 计算
    
    private func calculateFrames(for fragments: [RenderFragment]) {
        let oldHeight = contentHeight
        var y: CGFloat = 0

        fragmentFrames.removeAll(keepingCapacity: true)

        let width = maxWidth == .greatestFiniteMagnitude ? bounds.width : maxWidth

        for (index, fragment) in fragments.enumerated() {
            if index > 0 {
                y += effectiveSpacing
            }

            let indent = fragmentIndent(fragment)
            let availableWidth = width - indent
            let height = estimateHeight(for: fragment, maxWidth: availableWidth)

            fragmentFrames[fragment.fragmentId] = CGRect(
                x: indent,
                y: y,
                width: availableWidth,
                height: height
            )
            y += height
        }

        contentHeight = y
        invalidateIntrinsicContentSize()

        if contentHeight != oldHeight {
            onContentHeightChanged?(contentHeight)
        }
    }

    /// animationProgress 模式下，更新指定 fragment 的高度并重算 contentHeight
    /// 供 animator delegate 在 displayedLength 变化时调用
    public func updateContentHeightForAnimationProgress(fragmentId: String, displayedLength: Int) {
        guard animationConfig.fragmentHeightMode == .animationProgress else { return }
        guard let fragments = renderResult?.fragments,
              let index = fragments.firstIndex(where: { $0.fragmentId == fragmentId }),
              let vf = fragments[index] as? FragmentViewFactory else { return }

        let frame = fragmentFrames[fragmentId] ?? .zero
        let availableWidth = frame.width > 0 ? frame.width : (maxWidth == .greatestFiniteMagnitude ? bounds.width : maxWidth) - fragmentIndent(fragments[index])
        let newHeight = vf.estimatedHeight(atDisplayedLength: displayedLength, maxWidth: availableWidth, theme: theme)

        var newFrame = frame
        newFrame.size.height = newHeight
        fragmentFrames[fragmentId] = newFrame

        // 重算 contentHeight
        var y: CGFloat = 0
        for (i, fragment) in fragments.enumerated() {
            if i > 0 { y += effectiveSpacing }
            var f = fragmentFrames[fragment.fragmentId] ?? .zero
            f.origin.y = y
            fragmentFrames[fragment.fragmentId] = f
            y += f.height
        }
        contentHeight = y
        invalidateIntrinsicContentSize()
        onContentHeightChanged?(contentHeight)

        if let view = fragmentViews[fragmentId] {
            view.frame = fragmentFrames[fragmentId] ?? view.frame
        }
    }
    
    private func fragmentIndent(_ fragment: RenderFragment) -> CGFloat {
        (fragment as? FragmentViewFactory)?.context.indent ?? 0
    }
    
    private func estimateHeight(for fragment: RenderFragment, maxWidth: CGFloat) -> CGFloat {
        guard let vf = fragment as? FragmentViewFactory else {
            return spacingStyle.defaultFragmentHeight
        }
        if vf.estimatedSize.height > 0 {
            return vf.estimatedSize.height
        }
        return spacingStyle.defaultFragmentHeight
    }
    
    private func updateViewPositions() {
        for (fragmentId, view) in fragmentViews {
            if let frame = fragmentFrames[fragmentId] {
                UIView.animate(withDuration: animationStyle.layoutDuration) {
                    view.frame = frame
                }
            }
        }
    }
    
    // MARK: - Private: View 创建和复用
    
    private func createFragmentView(for fragment: RenderFragment) -> UIView {
        let view: UIView

        if let textFrag = fragment as? TextFragment, textFrag.context.blockQuoteDepth == 0 {
            view = dequeueOrCreate(reuseId: ReuseIdentifier.textView.rawValue) { [weak self] in
                MarkdownTextView(revealStrategyProvider: self?.animationConfig.revealStrategyProvider)
            }
        } else if let vf = fragment as? FragmentViewFactory {
            view = dequeueOrCreate(reuseId: vf.reuseIdentifier.rawValue, factory: vf.makeView)
        } else {
            view = UIView()
        }
        
        fragmentViews[fragment.fragmentId] = view
        if view.superview !== self {
            addSubview(view)
        }
        
        return view
    }
    
    private func configureFragmentView(_ view: UIView, with fragment: RenderFragment) {
        if let vf = fragment as? FragmentViewFactory {
            vf.configure(view, theme: theme)
            if let streamable = view as? StreamableContent {
                if let text = fragment as? TextFragment {
                    _ = streamable.updateContent(text.attributedString)
                } else if let viewFrag = fragment as? ViewFragment {
                    _ = streamable.updateContent(viewFrag.content)
                }
            }
        }
        
        // 事件上报：View → handleEvent → StateStore
        if let eventReporting = view as? FragmentEventReporting {
            eventReporting.onEvent = { [weak self] event in
                self?.handleEvent(event)
            }
        }
    }
    
    private func dequeueOrCreate(reuseId: String, factory: () -> UIView) -> UIView {
        if let recycled = reusePool[reuseId]?.popLast() {
            return recycled
        }
        return factory()
    }
    
    private func recycleView(_ view: UIView, reuseId: String) {
        view.alpha = AnimationConstants.visibleAlpha
        if reusePool[reuseId] == nil {
            reusePool[reuseId] = []
        }
        reusePool[reuseId]?.append(view)
    }
    
    /// 检查 View 类型是否与 Fragment 类型匹配
    private func isViewTypeMatching(_ view: UIView, for fragment: RenderFragment) -> Bool {
        guard let vf = fragment as? FragmentViewFactory else { return true }
        
        switch vf.reuseIdentifier {
        case .textView:
            return view is MarkdownTextView
        case .blockQuoteText:
            return view is BlockQuoteTextView
        case .codeBlockView:
            return view is CodeBlockView
        case .customCodeBlock:
            return true  // 自定义 View 类型，复用池按 reuseId 隔离即可
        case .markdownTableView:
            return view is MarkdownTableView
        case .thematicBreakView:
            return view is ThematicBreakView
        case .markdownImageView:
            return view is MarkdownImageView
        case .spacing:
            return !(view is MarkdownTextView) && !(view is BlockQuoteTextView)
        }
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // 如果宽度变化，重新计算 frames
        if let result = renderResult {
            let currentWidth = maxWidth == .greatestFiniteMagnitude ? bounds.width : maxWidth
            
            // 检查是否需要重新计算（使用 theme 中的阈值）
            let threshold = spacingStyle.widthChangeThreshold
            if fragmentFrames.isEmpty || abs(currentWidth - (fragmentFrames.values.first?.width ?? 0)) > threshold {
                calculateFrames(for: result.fragments)
                updateViewPositions()
            }
        }
    }
    
    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }
    
    // MARK: - Cleanup
    
    /// 清除所有内容
    public func clear() {
        animationDriver.reset()
        
        for (_, view) in fragmentViews {
            view.removeFromSuperview()
        }
        fragmentViews.removeAll()
        fragmentFrames.removeAll()
        renderResult = nil
        contentHeight = 0
        streamingBuffer = ""
        stateStore.gc(existingIds: [])
        
        invalidateIntrinsicContentSize()
    }
    
    /// 清除复用池
    public func clearReusePool() {
        reusePool.removeAll()
    }
}

// MARK: - FragmentAnimationDriverDelegate

extension MarkdownContainerView: FragmentAnimationDriverDelegate {
    public func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, createAndAddViewFor fragmentId: String) -> UIView? {
        guard let fragment = renderResult?.fragments.first(where: { $0.fragmentId == fragmentId }) else { return nil }
        let view = createFragmentView(for: fragment)
        configureFragmentView(view, with: fragment)
        if let streamable = view as? StreamableContent, let textFrag = fragment as? TextFragment {
            _ = streamable.updateContent(textFrag.attributedString)
        }
        view.frame = fragmentFrames[fragmentId] ?? .zero
        view.alpha = AnimationConstants.initialAlpha
        fragmentViews[fragmentId] = view
        addSubview(view)
        return view
    }

    public func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, didAddFragmentAt index: Int) {
        guard let fragments = renderResult?.fragments, index < fragments.count else { return }
        var y: CGFloat = 0
        for i in 0...index {
            if i > 0 { y += effectiveSpacing }
            let fragment = fragments[i]
            let height = fragmentFrames[fragment.fragmentId]?.height ?? (fragment as? FragmentViewFactory)?.estimatedSize.height ?? spacingStyle.defaultFragmentHeight
            y += height
        }
        contentHeight = y
        invalidateIntrinsicContentSize()
        onContentHeightChanged?(contentHeight)
    }

    public func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, contentHeightNeedsUpdateFor fragmentId: String, displayedLength: Int) {
        updateContentHeightForAnimationProgress(fragmentId: fragmentId, displayedLength: displayedLength)
    }
    
    // MARK: - Fragment 事件处理
    
    /// 统一事件处理入口（更新 StateStore → 触发 render）
    public func handleEvent(_ event: FragmentEvent) {
        switch event {
        case let e as CopyEvent:
            var state = stateStore.getState(CodeBlockInteractionState.self, for: e.fragmentId)
            state.isCopied = true
            stateStore.updateState(state, for: e.fragmentId)
            
            // 延迟后重置（使用主题配置）
            let fragmentId = e.fragmentId
            let duration = theme.code.block.header.copySuccessDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self = self else { return }
                var state = self.stateStore.getState(CodeBlockInteractionState.self, for: fragmentId)
                state.isCopied = false
                self.stateStore.updateState(state, for: fragmentId)
            }
        default:
            break
        }
    }
}
