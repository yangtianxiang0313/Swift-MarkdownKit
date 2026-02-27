# 流式动画系统重设计方案

> 从第一性原理出发，完整重设计动画逻辑，细化到每一步

---

## 一、现状问题分析

### 1.1 文本显示层

| 问题 | 当前实现 | 影响 |
|------|----------|------|
| **每帧全量替换** | Substring 策略：`attributedText = fullText.attributedSubstring(0..<N)` | 每帧创建新 NSAttributedString、替换 UITextView 内容，触发 TextKit 全量重排 |
| **双数据源** | fullAttributedText（内存） + textStorage（UITextView）需同步 | LayoutManager 策略的 syncStorage 与 updateContent 时序复杂，易不一致 |
| **LayoutManager 策略 O(N) 每帧** | 0..<safeLength 逐字符 setAttribute | 长文本时每帧 O(N) 操作，卡顿 |
| **UITextView 刷新不可靠** | 仅 set attributedText，依赖系统自动重绘 | 部分场景不触发 display/layout，需额外 setNeedsDisplay |
| **策略与内容分离** | 策略持 fullText 参数，View 持 fullAttributedText | 内容更新路径分散，reset 后 lastSyncedLength 丢失增量信息 |

### 1.2 动画驱动层

| 问题 | 当前实现 | 影响 |
|------|----------|------|
| **顺序串行** | currentPlayingIndex 一次只播一个 fragment | 设计正确，但进入动画阻塞时后续全部等待，可能显得卡顿 |
| **tickContinuousStrategies 全量遍历** | 每帧遍历所有 displayStrategies 检查 needsContinuousTick | 大部分策略为 false，浪费 |
| **DisplayLink 无节流** | 60fps 持续 tick | 无待播内容时仍可能空转（虽有 stopDisplayLink） |
| **策略生命周期** | 每 fragment 一个策略实例，update 时 reset | reset 清空 lastSyncedLength，无法利用增量信息 |

### 1.3 布局与 Frame 层

| 问题 | 当前实现 | 影响 |
|------|----------|------|
| **frame 基于完整内容** | estimateHeight 用 full attributedString.boundingRect | 正确，但 updateViewPositions 动画所有 view | 
| **updateViewPositions 全量** | applyDiff 后对 fragmentViews 全量执行 frame 动画 | 只变更一个 fragment 时，其余 19 个也做无意义动画 |
| **高度突变** | 内容从 1 行变 10 行时，frame 瞬间变化 | 若用 UIView.animate，会有过渡，但可能导致视觉跳动 |

### 1.4 Container 集成层

| 问题 | 当前实现 | 影响 |
|------|----------|------|
| **handleUpdate 分支复杂** | AnimatableContent / configureFragmentView 分支 | 非 AnimatableContent 的 View 不走 updateContent，无内容更新 |
| **createFragmentView 类型分支** | blockQuoteDepth==0 → MarkdownTextView，否则 makeView | 引用块、代码块等无 AnimatableContent |
| **View 复用与策略绑定** | 策略在 handleInsert 创建并存入 displayStrategies[id] | 复用 View 时若 fragmentId 变，策略可能错配（通常不会复用跨类型） |

### 1.5 时序与布局（核心）

| 问题 | 当前实现 | 影响 |
|------|----------|------|
| **View 超前创建** | applyDiff 时对所有 insert 立即 createFragmentView 并 addSubview | 后续 fragment 的 View 在动画未播到时就已加入布局 |
| **contentHeight 超前** | calculateFrames 用全部 fragment 算总高 | 整体高度立即等于「全部内容」，与实际可见进度不一致 |
| **布局与动画脱节** | 布局一次性完成，动画只控制「显示内容」 | 滚动区域高度错误、视觉上的空白跳跃、滚动条与内容不符 |

**正确语义**：上一个 fragment 动画未播完时，下一个 fragment 的 View **不应被创建**，也不应参与布局。contentHeight 应随「已加入布局的 fragment」逐步累加，由动画系统统一调度。

---

## 二、第一性原理与目标

### 2.1 核心目标（ARCHITECTURE_V2）

1. **逐字动画**：文字按可配置速率逐字显示
2. **进入动画**：每个 block 出现时有淡入/滑入等效果
3. **增量刷新**：新数据到达时，动画从当前位置继续，不重置
4. **内容修改**：检测 append/modified/truncated，正确处理回退

### 2.2 设计原则

1. **协议大于基类**：通过协议定义能力，不建 StreamableTextView 等基类；View 通过遵循协议获得动画能力
2. **组合大于继承**：reveal/update 等逻辑封装为可组合的 capability，View 持有并委托
3. **充分可配置**：Animator、进入动画、reveal 策略、速度策略均可注入或替换，外部可完全自定义动画逻辑
4. **策略与架构解耦**：TextRevealStrategy 不绑定具体实现（NSTextStorage、substring、mask 等），架构只依赖协议，实现可插拔
5. **动画接管时序**：有动画时，View 创建与布局由动画系统统一调度，不超前创建
6. **依赖倒置**：用户扩展时不应修改框架内部代码；高度计算等由用户在创建 Fragment 时注入 FragmentHeightProvider，框架零 switch

---

## 三、新架构概览

```
┌─────────────────────────────────────────────────────────────────────────┐
│ MarkdownContainerView                                                    │
│   applyDiff(changes)                                                    │
│   ├── 更新 renderResult、fragmentFrames（预计算全部，不创建 View）         │
│   ├── 调用 StreamAnimator.applyDiff(changes)  // 只传计划，不传 View      │
│   └── 不在此处 createFragmentView / addSubview                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ StreamAnimator（新版动画驱动，统一时序管理）                                │
│   状态：fragmentOrder, targetProgress, currentPlayingIndex, addedCount   │
│   职责：                                                                  │
│   - applyDiff: 更新 fragment 计划，不创建 View                           │
│   - tick: 若当前 fragment 无 View → 向 Container 请求 createAndAdd(id)    │
│           然后驱动 enter + reveal 动画                                    │
│   - 动画完成时：currentPlayingIndex++，下一帧 tick 再请求下一个 View       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │ 请求创建
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Container.createAndAddFragmentView(for fragmentId)                       │
│   仅在被 Animator 请求时调用                                              │
│   → createFragmentView（返回遵循 StreamableContent 的 view，组合 TextRevealStrategy 如 SubstringRevealStrategy）        │
│   → configure, addSubview, 更新 contentHeight                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ View : StreamableContent（协议能力，非基类）                                │
│   任意的 UIView 通过遵循 StreamableContent 获得动画能力                     │
│   实现方式：组合 TextRevealStrategy（如 SubstringRevealStrategy），委托 reveal/updateContent │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 四、统一时序管理（核心）

### 4.1 原则

**统一路径**：不区分 `animated == true/false` 分支，始终由动画驱动统一处理。

**无动画作为默认策略**：`InstantAnimationDriver` 实现 `FragmentAnimationDriver`，applyDiff 时立即创建全部 View、reveal 完整内容、不启动 tick。与有动画的 `StreamAnimator` 为同一协议的不同实现，可替换。

### 4.2 数据流对比

| 阶段 | 当前（错误） | 新设计 |
|------|-------------|--------|
| **applyDiff** | 对每个 insert 立即 createFragmentView + addSubview | 仅更新 renderResult、fragmentFrames，调用 animator.applyDiff(changes) |
| **contentHeight** | 全部 fragment 的 frame 累加 | 仅为「已加入布局」的 fragment 累加 |
| **View 创建时机** | 随 applyDiff 立即创建 | 随 tick 推进，播到 fragment N 时才 createAndAdd(fragment N) |

### 4.3 时序状态

```
StreamAnimator 维护：
- fragmentOrder: [String]           // 全部 fragment 顺序（来自最新 renderResult）
- targetProgress: [String: Int]     // 每个 fragment 的目标显示长度
- currentPlayingIndex: Int          // 当前正在播放的 fragment 下标
- lastAddedIndex: Int               // 最后一个已加入布局的 fragment 下标（即 addedCount - 1）

contentHeight 计算：
  height = 0
  for i in 0..<min(lastAddedIndex + 1, fragmentOrder.count):
      height += spacing (if i > 0)
      height += fragmentFrames[fragmentOrder[i]].height
```

### 4.4 applyDiff 新逻辑（Container）— 统一路径

```
1. 计算 changes = StreamingFragmentDiffer.diff(old, new)
2. self.renderResult = newResult
3. calculateFrames(for: newResult.fragments)
4. animationDriver.applyDiff(changes, fragments: newResult.fragments, frames: fragmentFrames)
5. contentHeight 由 delegate.didAddFragmentAt 回调中计算（两种 driver 均通过同一回调）
```

**无分支**：不区分 animated。Driver 决定行为：
- `StreamAnimator`：懒创建，tick 驱动，contentHeight 随 lastAddedIndex 累加
- `InstantAnimationDriver`：applyDiff 内一次性创建全部 View、reveal 完整、contentHeight = 全部累加，不启动 tick

### 4.5 tick 与 View 创建

```
tick() 开始：
1. fragmentId = fragmentOrder[currentPlayingIndex]
2. if views[fragmentId] == nil：
   - view = delegate.createAndAddFragmentView(for: fragmentId)  // Container 实现
   - views[fragmentId] = WeakRef(view)
   - lastAddedIndex = currentPlayingIndex
   - delegate.didAddFragmentView(at: currentPlayingIndex)  // Container 更新 contentHeight
3. 正常执行 enter + reveal 动画
4. 若本 fragment 动画完成：currentPlayingIndex++
5. 下一帧 tick：若 currentPlayingIndex 指向的 fragment 无 View，重复步骤 2
```

### 4.6 handleUpdate 的时序

- **update** 只作用于「已有 View」的 fragment。
- 若 fragment N 正在播放且有 View，收到 update：更新 View 内容，更新 targetProgress，动画继续。
- 若 fragment N 还未被创建（currentPlayingIndex > N 不会发生，因为顺序播放），则不会有 update 到未创建的 fragment。若 fragment 顺序中有 N 且 N 已被加入，则 N 可能收到 update。

**更精确**：update 针对 fragmentId。若该 fragment 的 View 已创建（在 fragmentViews 中），则走 handleUpdate。若未创建，说明还没播到，此时 applyDiff 中的 update 如何处理？—— 该 fragment 已在 fragmentOrder 中，其数据（如 attributedString）来自 renderResult。当我们播到它时，createAndAdd 会从最新的 renderResult 取 fragment，所以会拿到已更新的内容。因此，**未创建 View 的 fragment 的 update 不需要单独处理**，等 create 时用最新数据即可。

但 insert 之后可能有 update：例如先 insert fragment 0，还没播到时又 appendText，fragment 0 变为 update。若我们还没 create fragment 0 的 View，这个 update 只需更新 animator 内部的 targetProgress（若我们为未创建的 fragment 也存了 target）。create 时用最新 fragment 数据即可。

所以：对于 **update**，若 View 已存在，Container 调用 view.updateContent，animator.handleUpdate。若 View 不存在，animator 只需更新 targetProgress（若该 fragment 已在 fragmentOrder 中），等 create 时用最新 fragment。

### 4.7 handleInsert 的时序

- insert 时，fragment 被加入 fragmentOrder，targetProgress 设为目标长度。
- **不**创建 View。View 在 tick 播到该 fragment 时才创建。
- 若 currentPlayingIndex 已到结尾（无在播 fragment），applyDiff 后有新 insert，需要启动 tick：startDisplayLinkIfNeeded()。下一帧 tick 时，currentPlayingIndex 指向新 fragment，发现无 View，触发 create。

### 4.8 handleDelete 的时序

- 若被删 fragment 的 View 已创建：从 superview 移除，回收，animator.handleDelete。
- 若未创建：只从 fragmentOrder 移除，调整 currentPlayingIndex，不涉及 View。

### 4.9 contentHeight 更新时机

```
当 lastAddedIndex 增加时（即 createAndAddFragmentView 被调用时）：
  newContentHeight = 累加 fragmentFrames[fragmentOrder[0]] ... fragmentFrames[fragmentOrder[lastAddedIndex]]
  onContentHeightChanged?(newContentHeight)
```

当已存在的 fragment 的 frame 变化时（如 update 导致 estimatedHeight 变）：需重新计算该 fragment 及之后所有已加入的 fragment 的 y 位置，并更新 contentHeight。为简化，可规定：**流式场景下已加入的 fragment 的 frame 不变**（即不考虑 update 改变高度）。若允许，则需在 update 时重新 calculateFrames，并更新受影响 View 的 frame 与 contentHeight。

### 4.10 无动画 = InstantAnimationDriver 策略

无需单独分支。注入 `InstantAnimationDriver` 时：
- `applyDiff` 内遍历全部 fragments，立即 `createAndAdd` 每个 View
- 对 StreamableContent 调用 `reveal(upTo: totalLength)`，跳过 enter 动画
- `contentHeight` = 全部 fragment 累加
- 不启动 DisplayLink

与 `StreamAnimator` 同为 `FragmentAnimationDriver` 实现，通过配置切换，代码路径统一。

**API 简化**：`render()`、`apply()`、`appendText()` 内部均调用 `animationDriver.applyDiff()`，不再有 `animated` 参数。动画行为由注入的 driver 决定。

---

## 五、协议与组合设计（协议大于基类、组合大于继承）

### 5.1 协议定义

```swift
/// 流式动画能力协议 — Animator 与 View 的契约
protocol StreamableContent: UIView {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    func reveal(upTo length: Int)
    func updateContent(_ content: Any) -> ContentUpdateResult
    var enterAnimationConfig: EnterAnimationConfig? { get }
}
```

### 5.2 TextRevealStrategy 协议（与实现解耦）

协议**不绑定** NSTextStorage、TextKit 等具体技术。策略在初始化时绑定目标（View），内部实现自由选择：

```swift
/// 文本逐字揭示策略 — 接口与实现解耦
/// 架构只依赖此协议，不关心内部用 substring、NSTextStorage、mask 等
protocol TextRevealStrategy {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    mutating func reveal(upTo length: Int)
    mutating func updateContent(_ new: NSAttributedString) -> ContentUpdateResult
}
```

**内置实现（均可替换）**：

| 实现 | 方式 | 特点 | 适用 |
|------|------|------|------|
| **SubstringRevealStrategy** | `attributedText = fullText.attributedSubstring(0..<N)` | 最简单，无额外依赖 | 默认，用户可选 |
| **LayoutManagerRevealStrategy** | NSTextStorage + attribute | 增量刷新，性能更好 | 可选插入 |
| **AlphaFadeRevealStrategy** | 逐字符 alpha | 视觉效果柔和 | 可选 |

### 5.3 SubstringRevealStrategy（默认，最简单）

用户可用最简单的 substring 方案，无需 NSTextStorage：

```swift
struct SubstringRevealStrategy: TextRevealStrategy {
    private var fullAttributedText: NSAttributedString
    private var displayedLength: Int
    private weak var targetView: (UIView & AttributedTextDisplayable)?
    
    init(targetView: UIView & AttributedTextDisplayable) {
        self.targetView = targetView
        self.fullAttributedText = NSAttributedString()
        self.displayedLength = 0
    }
    
    mutating func reveal(upTo length: Int) {
        let safe = min(max(0, length), fullAttributedText.length)
        displayedLength = safe
        targetView?.displayAttributedText = safe == 0 ? nil : fullAttributedText.attributedSubstring(from: NSRange(0, safe))
    }
    
    mutating func updateContent(_ new: NSAttributedString) -> ContentUpdateResult {
        // diff 逻辑...
        fullAttributedText = new
        return result
    }
}
```

### 5.4 View 组合策略（策略可注入）

```swift
final class MarkdownTextView: UIView, StreamableContent {
    private let textView: UITextView
    private var revealStrategy: TextRevealStrategy  // 可替换，默认 SubstringRevealStrategy
    
    init(revealStrategy: TextRevealStrategy? = nil) {
        self.revealStrategy = revealStrategy ?? SubstringRevealStrategy(targetView: textView)
        ...
    }
    
    func reveal(upTo length: Int) { revealStrategy.reveal(upTo: length) }
    func updateContent(_ content: Any) -> ContentUpdateResult { ... }
}
```

策略在 init 时绑定 target（如 textView），后续 reveal/updateContent 无参数传递目标，架构对实现细节无感知。

### 5.5 可选实现：LayoutManagerRevealStrategy（NSTextStorage）

需要增量刷新时，可插拔使用基于 NSTextStorage 的实现。**架构不依赖它**，仅为可选策略之一：

- 内部使用 `textView.textStorage`，通过 `replaceCharacters`/`append` 做增量更新
- reveal 时通过 `addAttribute(.foregroundColor, .clear)` 控制可见范围，需维护 fullContentSnapshot 做属性恢复
- 详细算法见前文「方案 A/B/C」对比，此处不纳入架构核心

用户选用 `SubstringRevealStrategy` 时，无需引入 TextKit 依赖。

---

## 六、StreamAnimator 详细设计

### 6.1 状态

```swift
private var fragmentOrder: [String] = []
private var targetProgress: [String: Int] = [:]
private var currentPlayingIndex: Int = 0
private var lastAddedIndex: Int = -1       // 最后一个已加入布局的 fragment 下标
private var views: [String: WeakRef<UIView>] = [:]
private var enteredViews: Set<String> = []
private var isPaused: Bool = false
private var displayLink: CADisplayLink?
weak var delegate: StreamAnimatorDelegate?
```

### 6.2 协议与回调

Animator 只依赖 **StreamableContent** 协议（第四节定义），不依赖具体 View 类型。

**StreamAnimatorDelegate**（Container 实现）：
```swift
protocol StreamAnimatorDelegate: AnyObject {
    /// Animator 请求创建并加入布局，返回 view
    func streamAnimator(_ animator: StreamAnimator, createAndAddViewFor fragmentId: String) -> UIView?
    /// 已加入新 fragment，Container 更新 contentHeight
    func streamAnimator(_ animator: StreamAnimator, didAddFragmentAt index: Int)
}
```

### 6.3 applyDiff（替代 handleInsert，不创建 View）

```
输入：changes: [FragmentChange], fragments: [RenderFragment], frames: [String: CGRect]
1. 根据 changes 更新 fragmentOrder、targetProgress（update 时更新 target，insert 时追加，delete 时移除）
2. 缓存 fragments、frames 供 createAndAdd 使用
3. 若 fragmentOrder 非空且 currentPlayingIndex 有效：startDisplayLinkIfNeeded()
```

### 6.4 handleUpdate(fragmentId, updateResult)

```
1. 根据 updateResult.type：
   - .append: targetProgress[id] = updateResult.currentLength
   - .modified: 若 view.displayedLength > unchangedPrefix，view.reveal(upTo: unchangedPrefix)；targetProgress[id] = currentLength；recalculateCurrentPlayingIndex
   - .truncated: 同上，reveal(upTo: newLength)
2. startDisplayLinkIfNeeded()
```

### 6.5 tick() 单帧逻辑（含懒创建）

```
1. 若 isPaused，return
2. 若 currentPlayingIndex >= fragmentOrder.count：
   - stopDisplayLink，onComplete，return
3. fragmentId = fragmentOrder[currentPlayingIndex]
4. 若 views[fragmentId] == nil：
   - view = delegate.createAndAddViewFor(fragmentId)
   - if view == nil { currentPlayingIndex++; return }  // 创建失败，跳过
   - views[fragmentId] = WeakRef(view)
   - lastAddedIndex = currentPlayingIndex
   - delegate.didAddFragmentAt(currentPlayingIndex)
5. guard let view = views[fragmentId]?.value as? StreamableContent else { currentPlayingIndex++; return }
5. 进入动画：
   - 若 !enteredViews.contains(fragmentId)：
     - 执行 enterAnimationConfig
     - 若 blocksSubsequent：isPaused = true，completion 里 isPaused = false，return
   - enteredViews.insert(fragmentId)
6. 内容动画：
   - target = targetProgress[fragmentId] ?? view.totalLength
   - current = view.displayedLength
   - 若 current < target：
     step = baseCharsPerFrame * speedMultiplier（向上取整，至少 1）
     newLen = min(current + step, target)
     view.reveal(upTo: newLen)
   - 若 view.displayedLength >= target：currentPlayingIndex++
```

### 6.6 移除 tickContinuousStrategies

不再支持 AlphaFadeIn 这类需持续 tick 的策略。若后续需要，可单独为「需连续 tick 的 View」维护列表，仅对这些 View 调用 tick，而不是遍历所有 strategy。

---

## 七、可配置性与扩展点

外部可自定义动画、策略，或完全替换默认逻辑。各环节通过协议 + 依赖注入实现可配置。

### 7.1 扩展点总览

| 扩展点 | 协议/类型 | 注入方式 | 默认实现 |
|--------|-----------|----------|----------|
| **动画驱动** | FragmentAnimationDriver | Container 构造函数 | InstantAnimationDriver（无动画）或 StreamAnimator（有动画） |
| **进入动画** | EnterAnimationExecutor | AnimationConfiguration | DefaultEnterAnimationExecutor |
| **Reveal 策略** | TextRevealStrategy | View 创建时 / 配置 | SubstringRevealStrategy（默认） |
| **速度计算** | RevealSpeedStrategy | AnimationConfiguration | 线性：baseCharsPerFrame * multiplier |
| **View 工厂** | FragmentViewFactoryProvider | AnimationConfiguration | 内置 createFragmentView 逻辑 |

### 7.2 动画驱动可替换（整体替换）

Container 依赖协议而非具体类型，可注入自定义 Animator 完全替换默认逻辑：

```swift
protocol FragmentAnimationDriver: AnyObject {
    var delegate: FragmentAnimationDriverDelegate? { get set }
    
    func applyDiff(changes: [FragmentChange], fragments: [RenderFragment], frames: [String: CGRect])
    func handleUpdate(fragmentId: String, updateResult: ContentUpdateResult)
    func handleDelete(fragmentId: String)
    func skipToEnd()
    func reset()
}

// 两种实现，统一协议，无分支
// - InstantAnimationDriver：无动画，默认策略，applyDiff 内一次性完成
// - StreamAnimator：有动画，tick 懒创建

// Container 初始化
init(
    engine: MarkdownRenderEngine,
    animationDriver: FragmentAnimationDriver  // 必选注入，通常用 config.animationDriverProvider.makeDriver()
)
```

外部可实现 `FragmentAnimationDriver`，自定义 tick 逻辑、时序、是否懒创建等，完全接管动画。内置两种实现：
- **InstantAnimationDriver**：无动画，applyDiff 内一次性创建全部 View、reveal 完整，不启动 tick（可作为默认）
- **StreamAnimator**：有动画，懒创建 + tick 驱动

### 7.3 进入动画可配置

已有 `EnterAnimationExecutor` 协议，通过 `AnimationConfiguration.enterAnimationExecutor` 注入：

```swift
// 自定义进入动画
struct MyCustomEnterExecutor: EnterAnimationExecutor {
    func execute(_ view: UIView, config: EnterAnimationConfig, theme: MarkdownTheme, completion: @escaping () -> Void) {
        // 自定义实现，如 3D 翻转、粒子效果等
        completion()
    }
}

let config = AnimationConfiguration(enterAnimationExecutor: MyCustomEnterExecutor())
```

### 7.4 Reveal 策略可替换

协议与实现解耦，不绑定 NSTextStorage；View 可持有任意实现：

```swift
protocol TextRevealStrategy {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    mutating func reveal(upTo length: Int)
    mutating func updateContent(_ new: NSAttributedString) -> ContentUpdateResult
}

// SubstringRevealStrategy 为默认实现（最简单，无 TextKit 依赖）
// LayoutManagerRevealStrategy 为可选实现（需 NSTextStorage）
```

View 创建时注入策略：

```swift
// 默认
MarkdownTextView(revealStrategy: SubstringRevealStrategy(targetView: textView))

// 自定义：如 LayoutManager、Alpha 渐入等
MarkdownTextView(revealStrategy: LayoutManagerRevealStrategy(targetView: textView))
```

Container 的 `createFragmentView` 或 View 工厂可从 `AnimationConfiguration.revealStrategyProvider`（协议实现）获取策略。

### 7.5 速度策略可配置

每帧步长（charsPerFrame）的计算可抽象为策略：

```swift
protocol RevealSpeedStrategy {
    /// 根据当前队列大小、fragment 配置等，返回本帧应推进的字符数
    func charsPerFrame(
        currentLength: Int,
        targetLength: Int,
        fragmentId: String,
        contentConfig: ContentAnimationConfig?
    ) -> Int
}

// 默认：线性 baseCharsPerFrame * multiplier
struct LinearRevealSpeedStrategy: RevealSpeedStrategy { ... }

// 阶梯加速（类似 StreamingAnimator 的 DefaultStreamingSpeedStrategy）
struct TieredRevealSpeedStrategy: RevealSpeedStrategy { ... }
```

通过 `AnimationConfiguration.revealSpeedStrategy` 注入。

### 7.6 AnimationConfiguration 聚合

```swift
/// 协议优先，替代闭包工厂
public protocol FragmentAnimationDriverProvider { func makeDriver() -> FragmentAnimationDriver }
public protocol TextRevealStrategyProvider { func makeStrategy(for target: TextDisplayTarget) -> TextRevealStrategy }

public struct AnimationConfiguration {
    public var animationDriverProvider: FragmentAnimationDriverProvider
    public var revealStrategyProvider: TextRevealStrategyProvider
    public var enterAnimationExecutor: EnterAnimationExecutor
    public var revealSpeedStrategy: RevealSpeedStrategy
    public var baseCharsPerFrame: Int
    public var globalSpeedMultiplier: CGFloat
    
    /// 默认：InstantAnimationDriver、SubstringRevealStrategyProvider
    public static let `default` = AnimationConfiguration(
        animationDriverProvider: DefaultAnimationDriverProvider(),
        revealStrategyProvider: SubstringRevealStrategyProvider(),
        ...
    )
    
    /// 有动画：StreamAnimator 的 provider
    public static let animated = AnimationConfiguration(...)
    
    /// 使用 NSTextStorage 增量策略（可选）
    public static func withLayoutManagerReveal(...) -> AnimationConfiguration
}
```

### 7.7 配置注入链路

```
MarkdownContainerView(animationConfig: config)
    → animator = config.animationDriverProvider.makeDriver()
    → animator 内部使用 config.enterAnimationExecutor、revealSpeedStrategy
    → createFragmentView 时 config.revealStrategyProvider.makeStrategy(for: textView) 取策略，注入 View
```

---

## 八、Container 集成

### 8.1 createAndAddFragmentView（Delegate 实现）

Animator 在 tick 中请求时调用，**唯一**的 View 创建入口（流式有动画时）：

```
func streamAnimator(_ animator: StreamAnimator, createAndAddViewFor fragmentId: String) -> UIView? {
1. fragment = renderResult.fragments.first { $0.fragmentId == fragmentId }
2. guard let fragment else { return nil }
3. view = createFragmentView(for: fragment)
4. configureFragmentView(view, with: fragment)
5. if let streamable = view as? StreamableContent, let textFrag = fragment as? TextFragment {
     _ = streamable.updateContent(textFrag.attributedString)
   }
6. view.frame = fragmentFrames[fragmentId] ?? .zero
7. view.alpha = 0
8. fragmentViews[fragmentId] = view
9. addSubview(view)
10. return view
}
```

### 8.2 didAddFragmentAt（更新 contentHeight）

```
func streamAnimator(_ animator: StreamAnimator, didAddFragmentAt index: Int) {
  contentHeight = 累加 fragmentFrames[fragmentOrder[0]] ... fragmentOrder[index] 的 height + spacing
  onContentHeightChanged?(contentHeight)
}
```

### 8.3 handleUpdate 细化（仅作用于已存在的 View）

```
1. view = fragmentViews[oldFragment.fragmentId]
2. guard view != nil else { return }  // 未创建的 fragment 不处理，create 时用最新数据
3. 若 view 为 StreamableContent：
   - updateResult = view.updateContent(newFragment 的 attributedString)
   - 内部由 reveal 策略处理（Substring 替换 attributedText，LayoutManager 则操作 textStorage）
3. 若 view 非 StreamableContent：
   - 走原有 configureFragmentView
4. 仅当 fragment 的 frame 发生变更时，对该 view 做 frame 动画：
   - 计算新旧 frame
   - 若不同：UIView.animate { view.frame = newFrame }
5. streamAnimator.handleUpdate(fragmentId, updateResult)
```

### 8.4 updateViewPositions 优化

**当前**：对所有 fragmentViews 执行 frame 动画。

**新逻辑**：只对「frame 发生变化的 fragment」做动画。

```
changes 中涉及 insert/update 的 fragmentIds = affectedIds
for id in affectedIds:
    if let view = fragmentViews[id], let newFrame = fragmentFrames[id], view.frame != newFrame:
        UIView.animate { view.frame = newFrame }
```

其余未变化的不动，避免无意义动画。

### 8.5 Frame 计算

保持不变：用 Fragment 的 estimatedSize（基于完整内容 boundingRect）。流式时每次 applyDiff 都重新 calculateFrames，用最新 fragment 的 estimatedSize。

---

## 九、边界情况

### 9.1 快速连续 appendText

- appendText 会多次调用 applyDiff，可能同一 fragment 连续 update。
- StreamAnimator.handleUpdate 只更新 targetProgress，不重置 displayedLength。
- tick 会持续推进，无问题。

### 9.2 内容中间被修改

- updateContent 返回 .modified(unchangedPrefixLength)
- handleUpdate 中若 displayedLength > unchangedPrefix，先 reveal(upTo: unchangedPrefix)
- 再更新 targetProgress，动画从安全位置继续。

### 9.3 View 复用

- 遵循 StreamableContent 的 View 从 pool 取出时，需 reset：reveal 策略清空 contentSnapshot、displayedLength。
- recycleView 时调用 view.prepareForReuse() 或让 View 实现 prepareForReuse 重置 capability。

### 9.4 非文本 Fragment

- CodeBlockView、MarkdownTableView 等通过**遵循 StreamableContent** 获得动画能力：
  - 可组合各自的 capability（如 CodeRevealCapability），或提供简单实现
  - displayedLength / totalLength 按内容长度；reveal(upTo:) 空实现或直接显示全部
  - enterAnimationConfig 照常
- 或保留「非 StreamableContent 则跳过内容动画」的兼容路径；协议设计允许按需扩展。

---

## 十、实现步骤

> **可执行开发规格**：详见 [ANIMATION_IMPLEMENTATION_SPEC.md](./ANIMATION_IMPLEMENTATION_SPEC.md)，含分阶段任务、验收标准与技术决策点。

### Phase 1：协议与 SubstringRevealStrategy

1. 定义 StreamableContent、TextRevealStrategy 协议
2. 实现 SubstringRevealStrategy（默认，attributedSubstring 方案）
3. MarkdownTextView 组合 TextRevealStrategy 并实现 StreamableContent
4. 单元测试：reveal 推进、updateContent 返回 append/modified/truncated

### Phase 2：FragmentAnimationDriver 与两种实现

1. 定义 FragmentAnimationDriver、FragmentAnimationDriverDelegate
2. InstantAnimationDriver（无动画）、StreamAnimator（有动画，懒创建）
3. RevealSpeedStrategy 协议 + LinearRevealSpeedStrategy
4. 移除 AnimationController、TextDisplayStrategy、displayStrategies、tickContinuousStrategies

### Phase 3：Container 集成

1. 用 FragmentAnimationDriver 替换 AnimationController
2. applyDiff 重写：只传计划给 driver，不在此处 createFragmentView
3. 实现 delegate：createAndAddViewFor、didAddFragmentAt
4. updateViewPositions 仅更新 affectedIds

### Phase 4：清理

1. 删除旧 Animation 相关文件（见实现规格文档）
2. MarkdownTextView 移除 AnimatableContent、TextContentStorage
3. AnimationConfiguration 使用 revealStrategyProvider（协议）取代 textDisplayStrategyFactory

---

## 十一、文件结构（目标）

```
Animation/
├── FragmentAnimationDriver.swift   # 动画驱动协议（可替换）
├── InstantAnimationDriver.swift   # 无动画实现（可选默认）
├── StreamAnimator.swift            # 有动画实现
├── StreamableContent.swift        # StreamableContent 协议
├── TextRevealStrategy.swift        # TextRevealStrategy 协议 + TextRevealCapability 默认实现
├── RevealSpeedStrategy.swift      # RevealSpeedStrategy 协议 + LinearRevealSpeedStrategy 默认实现
├── AnimationConfig.swift          # EnterAnimationConfig、ContentAnimationConfig、ContentUpdateResult
├── AnimationConfiguration.swift   # 聚合各可配置项
├── EnterAnimationExecutor.swift   # 协议 + Default/Spring 实现
└── AnimationConstants.swift       # 常量

Views/MarkdownTextView.swift       # 组合 TextRevealStrategy，遵循 StreamableContent

移除：
├── AnimationController.swift
├── AnimatableContent.swift
├── TextDisplayStrategy.swift
├── AttributedTextDisplayable.swift
└── Strategies/
    ├── SubstringDisplayStrategy.swift
    ├── AlphaFadeInDisplayStrategy.swift
    └── LayoutManagerDisplayStrategy.swift
```

---

*文档版本：2026-02-27*
