# 动画模块梳理文档

> 从第一性原理出发，基于 ARCHITECTURE_V2 目标梳理动画需求，并对照当前实现

---

## 一、第一性原理：ARCHITECTURE_V2 定义的动画目标

### 1.1 最终目标（顶层需求）

> 一个复杂的超 Markdown 格式数据，能够**按可自定义速率**播放的 UI 动画：

| 效果类型 | 目标 |
|---------|------|
| **文字部分** | 逐字动画（打字机效果） |
| **View 部分** | 进入动画 + 内部内容逐字动画 |
| **增量刷新** | 只更新变化的部分，动画从当前位置继续 |

### 1.2 动画进度不中断的三层保障

```
层 1：稳定的 Fragment ID（结构位置，非内容哈希）
    → Diff 识别为 update 而非 delete + insert

层 2：View 复用 + 数据/进度分离
    → fullContent 可更新，displayedLength 不随更新重置

层 3：AnimationController 只更新目标，不重置进度
    → targetProgress[fragmentId] 更新，currentPlayingIndex 不变
```

### 1.3 内容修改处理（ARCHITECTURE_V2 设计）

| 变更类型 | 处理方式 |
|---------|----------|
| `.append` | 只更新 targetProgress，动画继续 |
| `.modified` | 若 displayedLength > commonPrefixLength，回退到安全位置 |
| `.truncated` | 回退 displayedLength 到 newLength |
| `.unchanged` | 不处理 |

### 1.4 协议与配置要求

- **AnimatableContent**：enterAnimationConfig、contentAnimationConfig、displayedContentLength、setDisplayedContentLength、updateContent
- **TextContentStorage**：fullAttributedText、previousPlainText、contentView（AttributedTextDisplayable）
- **DisplayOnlyContent**：无内容动画（图片等）
- **EnterAnimationConfig**：fadeIn、slideUp、expand、none、custom
- **ContentAnimationConfig**：speedMultiplier、granularity（character/word/line）
- **ContentUpdateResult**：unchanged、append、modified、truncated

---

## 二、当前动画模块结构

```
Animation/
├── AnimationController.swift       # 流式 Diff 时的动画调度（唯一入口）
├── AnimationConfiguration.swift   # 策略工厂、执行器、速度等
├── AnimationConfig.swift          # EnterAnimationConfig、ContentAnimationConfig、ContentUpdateResult
├── AnimationConstants.swift       # 常量
├── AnimatableContent.swift        # 协议 + TextContentStorage + DisplayOnlyContent 默认实现
├── AttributedTextDisplayable.swift # UILabel/UITextView 统一协议
├── EnterAnimationExecutor.swift   # Default / Spring 执行器
└── Strategies/
    ├── TextDisplayStrategy.swift      # 逐字显示策略协议
    ├── SubstringDisplayStrategy.swift # substring 截断
    └── AlphaFadeInDisplayStrategy.swift # Alpha 渐入（需持续 tick）

Streaming/
├── StreamingAnimator.swift        # 独立模块，未接入 ContainerView
├── StreamingSpeedStrategy.swift  # 打字机速度策略
└── StreamingTextBuffer.swift     # 文本缓冲、节流
```

---

## 三、AnimationController 当前逻辑

### 3.1 核心状态

| 状态 | 说明 |
|------|------|
| `targetProgress[fragmentId]` | 目标显示长度 |
| `fragmentOrder` | Fragment 顺序 |
| `currentPlayingIndex` | 当前播放位置 |
| `views[fragmentId]` | WeakRef<UIView> |
| `displayStrategies[fragmentId]` | TextDisplayStrategy 实例 |
| `enteredViews` | 已播放进入动画的 fragmentId |
| `isPaused` | 进入动画阻塞期间为 true |

### 3.2 数据流

```
applyDiff(changes)
    → handleInsert / handleUpdate / handleDelete

handleInsert(fragmentId, view, at)
    → view as? AnimatableContent
        → 是：setDisplayedContentLength(0)，注册 displayStrategy，targetProgress = totalContentLength
        → 否：currentPlayingIndex++（跳过）
    → startDisplayLinkIfNeeded()

handleUpdate(fragmentId, updateResult)
    → 根据 UpdateType 更新 targetProgress，必要时回退 displayedLength

tick() [每帧]
    → 取 fragmentOrder[currentPlayingIndex]
    → view as? AnimatableContent
        → 是：tickAnimatableView
        → 否：currentPlayingIndex++
    → tickContinuousStrategies()（AlphaFadeIn 等需持续更新）
```

### 3.3 tickAnimatableView 逻辑

```
1. 进入动画：未 entered 则执行 enterAnimationConfig，blocksSubsequent 时 isPaused=true
2. 内容动画：current < target 时，每帧 step = baseCharsPerFrame * speedMultiplier，调用 setDisplayedContentLength
3. 完成判断：displayedContentLength >= target → currentPlayingIndex++
```

### 3.4 与 ARCHITECTURE_V2 的对应关系

| ARCHITECTURE_V2 设计 | 当前实现 | 状态 |
|---------------------|---------|------|
| targetProgress 模式 | ✅ | 已实现 |
| handleInsert/Update/Delete | ✅ | 已实现 |
| ContentUpdateResult 四种类型 | ✅ | 已实现 |
| 进入动画 + blocksSubsequent | ✅ | 已实现 |
| recalculateCurrentPlayingIndex | ✅ | modified 时调用 |
| TextDisplayStrategy 可注入 | ✅ | AnimationConfiguration |
| AttributedTextDisplayable 统一 | ✅ | UILabel/UITextView 均支持 |
| TableContentStorage | ❌ | 未实现 |
| textLabels 降级（纯 UILabel） | ❌ | 已移除，仅 AnimatableContent |

---

## 四、AnimatableContent 实现现状

### 4.1 已实现 AnimatableContent 的 View

| View | 实现方式 | 覆盖场景 |
|------|---------|----------|
| **MarkdownTextView** | AnimatableContent + TextContentStorage | 纯文本段落（blockQuoteDepth == 0） |

### 4.2 未实现 AnimatableContent 的 View

| View | 当前协议 | 覆盖场景 |
|------|----------|----------|
| **BlockQuoteTextView** | UIView | 引用块内文本（blockQuoteDepth > 0） |
| **CodeBlockView** | FragmentView, FragmentEventReporting | 代码块 |
| **MarkdownTableView** | FragmentConfigurable | 表格 |
| **MarkdownImageView** | FragmentConfigurable | 图片 |

### 4.3 createFragmentView 分支逻辑

```swift
// MarkdownContainerView.createFragmentView
if let textFrag = fragment as? TextFragment, textFrag.context.blockQuoteDepth == 0 {
    // → MarkdownTextView（AnimatableContent）✅
    view = dequeueOrCreate(reuseId: .textView) { MarkdownTextView(displayStrategy: ...) }
} else if let vf = fragment as? FragmentViewFactory {
    // blockQuoteDepth > 0 → BlockQuoteTextView ❌
    // ViewFragment → CodeBlockView / MarkdownTableView / ... ❌
    view = dequeueOrCreate(reuseId: vf.reuseIdentifier, factory: vf.makeView)
}
```

**结论**：当前仅有**纯文本段落**参与流式动画；引用块、代码块、表格、图片均不参与。

---

## 五、TextContentStorage 与 AttributedTextDisplayable

### 5.1 当前设计（已支持 UITextView）

```swift
// TextContentStorage 要求
var contentView: UIView & AttributedTextDisplayable { get }

// AttributedTextDisplayable：UILabel 和 UITextView 均遵循
protocol AttributedTextDisplayable {
    var displayAttributedText: NSAttributedString? { get set }
}
```

**结论**：TextDisplayStrategy 已抽象为 `AttributedTextDisplayable`，UILabel 与 UITextView 均可作为逐字显示目标。ANIMATION_MODULE_OVERVIEW 此前「要求 contentLabel: UILabel」的表述已过时。

### 5.2 MarkdownTextView 结构

- 内部持有 `UITextView`
- `contentView` 返回该 `UITextView`
- 实现 AnimatableContent + TextContentStorage
- 支持链接等富文本（通过 UITextView）

---

## 六、StreamingAnimator 与 AnimationController 对比

| 维度 | AnimationController | StreamingAnimator |
|------|---------------------|-------------------|
| **集成** | ✅ 内嵌于 MarkdownContainerView | ❌ 未集成，需宿主主动调用 |
| **驱动** | CADisplayLink tick | CADisplayLink displayLinkFire |
| **文本 View** | AnimatableContent（含 MarkdownTextView） | PendingTextItem.label: UILabel |
| **UITextView** | ✅ 通过 AttributedTextDisplayable | ❌ handleTextViewInsert 仅淡入 |
| **目标进度** | targetProgress + 每帧趋近 | revealedLength 直接推进 |
| **内容修改** | ContentUpdateResult 处理 | 无 |
| **速度策略** | globalSpeedMultiplier + speedMultiplier | StreamingSpeedStrategy（阶梯加速等） |
| **快进** | skipToEnd() | fastForward()、finish() |

**结论**：AnimationController 是当前唯一生效的动画入口，设计上已对齐 ARCHITECTURE_V2；StreamingAnimator 为独立可选模块，与 ContainerView 未打通。

---

## 七、动画数据流（实际）

### 7.1 纯文本段落（blockQuoteDepth == 0）— 有动画

```
appendText("Hello")
    → applyDiff
    → handleInsert(TextFragment, at: 0)
    → createFragmentView → MarkdownTextView
    → animatable.updateContent(attributedString)
    → animationController.handleInsert
    → view as? AnimatableContent → true
    → setDisplayedContentLength(0), targetProgress = length
    → tick() 驱动逐字显示 + 进入动画
```

### 7.2 引用块内文本、代码块、表格、图片 — 无动画

```
handleInsert
    → createFragmentView → BlockQuoteTextView / CodeBlockView / ...
    → animationController.handleInsert
    → view as? AnimatableContent → false
    → currentPlayingIndex++（或跳过）
    → 无逐字动画，仅有 alpha 初始值
```

---

## 八、与 ARCHITECTURE_V2 的差距

| 项目 | 期望 | 现状 |
|------|------|------|
| CodeBlockView 逐字动画 | AnimatableContent + TextContentStorage | 未实现 |
| MarkdownTableView 逐字动画 | AnimatableContent + TableContentStorage | 未实现 |
| MarkdownImageView 进入动画 | AnimatableContent + DisplayOnlyContent | 未实现 |
| BlockQuoteTextView 逐字动画 | AnimatableContent + TextContentStorage | 未实现 |
| 引用块内文本 | 同普通段落 | 使用 BlockQuoteTextView，无动画 |

---

## 九、改造建议

### 9.1 短期（补齐核心场景）

1. **BlockQuoteTextView**：实现 AnimatableContent + TextContentStorage，内部 textView 作为 contentView
2. **CodeBlockView**：实现 AnimatableContent + TextContentStorage，codeLabel 作为 contentView（或统一为 AttributedTextDisplayable）

### 9.2 中长期（ARCHITECTURE_V2 对齐）

1. **MarkdownTableView**：实现 AnimatableContent + TableContentStorage（ARCHITECTURE_V2 有 TableContentStorage 设计）
2. **MarkdownImageView**：实现 AnimatableContent + DisplayOnlyContent

### 9.3 StreamingAnimator

- 保持为可选模块，供需要阶梯加速、fastForward 等能力的宿主使用
- 若接入 ContainerView，需改造 PendingTextItem 支持 `UIView & AttributedTextDisplayable`

---

## 十、文件与依赖关系

```
MarkdownContainerView
    ├── AnimationController
    │       ├── AnimationConfiguration
    │       │       ├── textDisplayStrategyFactory → SubstringDisplayStrategy / AlphaFadeInDisplayStrategy
    │       │       └── enterAnimationExecutor → DefaultEnterAnimationExecutor / SpringEnterAnimationExecutor
    │       ├── AnimatableContent
    │       │       ├── MarkdownTextView ✅
    │       │       ├── BlockQuoteTextView ❌
    │       │       ├── CodeBlockView ❌
    │       │       ├── MarkdownTableView ❌
    │       │       └── MarkdownImageView ❌
    │       └── TextDisplayStrategy（操作 AttributedTextDisplayable）
    └── createFragmentView
            ├── TextFragment, blockQuoteDepth==0 → MarkdownTextView
            ├── TextFragment, blockQuoteDepth>0 → BlockQuoteTextView (via makeView)
            └── ViewFragment → CodeBlockView / MarkdownTableView / ... (via makeView)

StreamingAnimator（未集成）
    ├── PendingTextItem(label: UILabel)
    └── StreamingSpeedStrategy
```

---

## 十一、总结

| 主题 | 结论 |
|------|------|
| **第一性目标** | 逐字动画、进入动画、增量刷新，ARCHITECTURE_V2 已定义 |
| **AnimationController** | 已实现目标进度、ContentUpdateResult、顺序播放，设计正确 |
| **AttributedTextDisplayable** | 已统一 UILabel/UITextView，无需再改 |
| **AnimatableContent 覆盖** | 仅 MarkdownTextView（纯文本段落）实现；引用块、代码块、表格、图片未实现 |
| **StreamingAnimator** | 独立模块，依赖 UILabel，与 ContainerView 未打通 |

**核心结论**：动画架构和 Controller 逻辑已基本对齐 ARCHITECTURE_V2，主要缺口在让更多 View（BlockQuoteTextView、CodeBlockView、MarkdownTableView、MarkdownImageView）实现 AnimatableContent。

---

*文档版本：2026-02-27*
