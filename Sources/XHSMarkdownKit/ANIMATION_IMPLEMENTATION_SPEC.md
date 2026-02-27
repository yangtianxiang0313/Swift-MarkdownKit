# 动画系统重设计 — 可执行开发规格

> 基于 ANIMATION_SYSTEM_REDESIGN.md，按**最优方案优先**规则：直达目标、无过渡层、综合权衡（扩展性 + 可说明性）

---

## 前置依赖

**高度改造方案**：[FRAGMENT_HEIGHT_REFACTOR.md](./FRAGMENT_HEIGHT_REFACTOR.md)

- 支持高度模式配置（fullContent / animationProgress）
- 高度由各 View 静态方法实现
- 动画改造依赖该方案提供的 `estimatedHeight(atDisplayedLength:)` 及 contentHeight 更新入口

**实施顺序**：先完成 FRAGMENT_HEIGHT_REFACTOR，再执行本规格。

---

## 一、技术决策（已确定）

| 编号 | 决策 | 结论 |
|-----|------|------|
| D1 | 非文本 Fragment + 自定义 View | CodeBlock、BlockQuote 实现 StreamableContent；自定义 View 遵循协议即接入；提供 SimpleStreamableContent 扩展辅助 |
| D2 | updateContent diff | 抽取 ContentChangeAnalyzer |
| D3 | Delegate | FragmentAnimationDriverDelegate |
| D4 | Theme | driver 持有，Container 注入 |
| D5 | 文本显示目标 | 新建 `TextDisplayTarget` 协议（UILabel/UITextView 遵循），替代 AttributedTextDisplayable；支持 SubstringRevealStrategy、LayoutManagerRevealStrategy 等可插拔策略 |
| D6 | render/appendText | 无 animated 参数 |
| D7 | 高度模式 | 见 FRAGMENT_HEIGHT_REFACTOR；AnimationConfiguration.fragmentHeightMode：fullContent / animationProgress |

---

## 二、高度计算（依赖 FRAGMENT_HEIGHT_REFACTOR）

高度方案由 [FRAGMENT_HEIGHT_REFACTOR.md](./FRAGMENT_HEIGHT_REFACTOR.md) 单独定义，此处仅说明与动画的衔接。

### 2.1 高度模式（AnimationConfiguration）

| 模式 | 说明 |
|------|------|
| **fullContent** | 始终使用完整内容高度（当前行为） |
| **animationProgress** | 高度跟随 displayedLength；当前 fragment 用 View 静态方法按进度算高 |

### 2.2 与动画的衔接

- **StreamAnimator.tick**：reveal 后若 `fragmentHeightMode == .animationProgress`，通过 delegate 通知 Container 更新 contentHeight
- **Container**：调用 `fragment.estimatedHeight(atDisplayedLength:view.displayedLength, maxWidth:, theme:)`，更新当前 fragment frame.height 与 contentHeight
- **View 静态方法**：各 View 实现 `estimatedHeight(content, displayedLength, maxWidth)`，详见高度改造方案

---

## 三、阶段划分与验收标准

### Phase 1：协议与 SubstringRevealStrategy

| 序号 | 任务 | 输出 | 验收标准 |
|-----|------|------|----------|
| 1.1 | 定义 `StreamableContent` 协议 | StreamableContent.swift | displayedLength, totalLength, reveal(upTo:), updateContent(_:), enterAnimationConfig |
| 1.2 | 新建 `TextDisplayTarget` 协议 | TextDisplayTarget.swift | `var displayAttributedText: NSAttributedString? { get set }`；UILabel/UITextView 扩展遵循；UITextView setter 需 setNeedsDisplay/setNeedsLayout |
| 1.3 | 定义 `TextRevealStrategy` 协议 | TextRevealStrategy.swift | displayedLength, totalLength, reveal(upTo:), updateContent(_:)；不绑定 NSTextStorage |
| 1.4 | 实现 `SubstringRevealStrategy` | 同文件 | init(targetView: TextDisplayTarget)；reveal 用 attributedSubstring 写回 targetView；updateContent 用 ContentChangeAnalyzer |
| 1.5 | 抽取 `ContentChangeAnalyzer` | ContentChangeAnalyzer.swift | 静态 `analyze(oldPlain: String, new: NSAttributedString) -> ContentUpdateResult` |
| 1.6 | MarkdownTextView 实现 StreamableContent | - | 组合 TextRevealStrategy，默认 SubstringRevealStrategy(targetView: textView)；可注入 strategy |
| 1.7 | 单元测试 | 测试 | reveal 推进；updateContent 返回 append/modified/truncated 正确 |

**完成后**：MarkdownTextView 可被 StreamableContent 驱动。

---

### Phase 2：FragmentAnimationDriver 与两种实现

| 序号 | 任务 | 输出 | 验收标准 |
|-----|------|------|----------|
| 2.1 | 定义 `FragmentAnimationDriver` + `FragmentAnimationDriverDelegate` | FragmentAnimationDriver.swift | applyDiff, handleUpdate, handleDelete, skipToEnd, reset；createAndAddViewFor, didAddFragmentAt |
| 2.2 | 实现 `InstantAnimationDriver` | InstantAnimationDriver.swift | applyDiff 内遍历 createAndAdd；StreamableContent 则 reveal(upTo: totalLength) |
| 2.3 | 实现 `StreamAnimator` | StreamAnimator.swift | applyDiff 只更新计划；tick 懒创建 + enter + reveal |
| 2.4 | `RevealSpeedStrategy` 协议 + `LinearRevealSpeedStrategy` | RevealSpeedStrategy.swift | `charsPerFrame(currentLength, targetLength, fragmentId, contentConfig?) -> Int`；默认 baseCharsPerFrame * multiplier；可扩展为阶梯加速等 |
| 2.5 | StreamAnimator 使用 RevealSpeedStrategy | - | 从 config 注入，支持自定义速度策略 |
| 2.6 | 单元/集成测试 | 测试 | Instant 一次完成；StreamAnimator 懒创建、逐字推进 |

**完成后**：两种 driver 可独立运行，速度策略可替换。

---

### Phase 3：Container 集成 + 多 View 类型 StreamableContent

| 序号 | 任务 | 验收标准 |
|-----|------|----------|
| 3.1 | FragmentAnimationDriver 替换 AnimationController | driver 由 config 创建；delegate = self |
| 3.2 | 重写 applyDiff + apply 统一 | diff → renderResult → calculateFrames → driver.applyDiff；apply() 改为复用 applyDiff 逻辑；移除 applyFragments |
| 3.3 | 实现 delegate | createAndAddViewFor、didAddFragmentAt；contentHeightNeedsUpdateFor（heightMode==.animationProgress 时生效） |
| 3.4 | handleInsert 移除 | handleUpdate/Delete 调用 driver |
| 3.5 | updateViewPositions | 只更新 affectedIds |
| 3.6 | createFragmentView 注入 strategy | blockQuoteDepth==0：MarkdownTextView(revealStrategyProvider: config.revealStrategyProvider.makeStrategy(for: textView))；provider 遵循 `TextRevealStrategyProvider` 协议 |
| 3.7 | CodeBlockView 实现 StreamableContent | 组合策略；reveal 控制 code 文本显示进度 |
| 3.8 | BlockQuoteTextView 实现 StreamableContent | 组合 SubstringRevealStrategy(targetView: textView) |
| 3.9 | MarkdownTableView 实现 StreamableContent | displayedLength=totalLength；reveal(upTo:) 直接显示全部；参与进入动画 |
| 3.10 | SimpleStreamableContent 扩展 | StreamableContent 的 extension：displayedLength=totalLength、reveal 空实现；用于「只需进入动画、无内容逐字」的 View |
| 3.11 | AnimationConfiguration | animationDriverProvider、revealStrategyProvider（协议，非闭包）、revealSpeedStrategy、fragmentHeightMode；theme 注入 driver |
| 3.12 | 自定义 View 接入文档 | 说明遵循 StreamableContent 即接入；SimpleStreamableContent 用法；LayoutManagerRevealStrategy 可插拔 |

**验收**：流式时 Instant 立即显示；StreamAnimator 懒创建 + 逐字动画；CodeBlock、BlockQuote、MarkdownTableView 均可参与；自定义 View 有清晰接入说明。

---

### Phase 4：清理

| 序号 | 任务 | 验收标准 |
|-----|------|----------|
| 4.1 | 删除旧实现 | AnimationController、AnimatableContent、TextDisplayStrategy、AttributedTextDisplayable、Strategies/ 下三个 |
| 4.2 | MarkdownTextView、AnimationConfiguration | 只保留 StreamableContent + TextRevealStrategy；revealStrategyProvider、revealSpeedStrategy |
| 4.3 | Example 验证 | 流式、非流式、skipAnimation、CodeBlock、BlockQuote、MarkdownTableView 正常 |

---

## 四、自定义 View 接入（扩展口）

### 4.1 接入方式

任意 UIView 遵循 `StreamableContent` 即参与动画；非遵循者在 tick 时被跳过。

用户通过自定义 Renderer 的 `makeView` 返回 StreamableContent View 即可接入。

### 4.2 扩展点说明

| 扩展点 | 说明 |
|--------|------|
| **StreamableContent 协议** | 核心契约；View 实现即可参与 enter + reveal 动画 |
| **TextRevealStrategy** | 可替换；SubstringRevealStrategy 默认；LayoutManagerRevealStrategy 可选（需 NSTextStorage） |
| **RevealSpeedStrategy** | 可替换；LinearRevealSpeedStrategy 默认；可扩展阶梯加速等 |
| **SimpleStreamableContent** | 辅助 extension：displayedLength=totalLength，reveal 空实现；适用于图片、分割线等「只需进入动画」的 View |
| **FragmentViewFactory.makeView** | 用户自定义 Renderer 创建 ViewFragment 时，makeView 返回 StreamableContent View |

### 4.3 示例

```swift
// 有内容逐字：实现完整 StreamableContent
final class MyStreamingView: UIView, StreamableContent {
    var displayedLength: Int { _displayedLength }
    var totalLength: Int { _fullContent.count }
    var enterAnimationConfig: EnterAnimationConfig? { .default }
    func reveal(upTo length: Int) { ... }
    func updateContent(_ content: Any) -> ContentUpdateResult { ... }
}

// 只需进入动画：遵循 SimpleStreamableContent（extension 提供默认实现）
final class MyDisplayOnlyView: UIView, StreamableContent, SimpleStreamableContent {}
```

### 4.4 文档

在 ARCHITECTURE_V2 或 CUSTOM_VIEW_ANIMATION.md 中说明：如何让自定义 Fragment View 遵循 StreamableContent、何时使用 SimpleStreamableContent、如何替换 RevealStrategy/SpeedStrategy。

---

## 五、类型与 API 规格

### 5.1 TextDisplayTarget

```swift
/// 可接收并显示富文本的 View（UILabel、UITextView）
/// 供 SubstringRevealStrategy、LayoutManagerRevealStrategy 等策略绑定目标
public protocol TextDisplayTarget: AnyObject {
    var displayAttributedText: NSAttributedString? { get set }
}

extension UILabel: TextDisplayTarget { ... }
extension UITextView: TextDisplayTarget { ... }
```

### 5.2 StreamableContent

```swift
protocol StreamableContent: UIView {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    func reveal(upTo length: Int)
    func updateContent(_ content: Any) -> ContentUpdateResult
    var enterAnimationConfig: EnterAnimationConfig? { get }
}
```

### 5.3 TextRevealStrategy + SubstringRevealStrategy

```swift
protocol TextRevealStrategy {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    mutating func reveal(upTo length: Int)
    mutating func updateContent(_ new: NSAttributedString) -> ContentUpdateResult
}

struct SubstringRevealStrategy: TextRevealStrategy {
    init(targetView: TextDisplayTarget)
}
```

### 5.4 RevealSpeedStrategy

```swift
protocol RevealSpeedStrategy {
    func charsPerFrame(
        currentLength: Int,
        targetLength: Int,
        fragmentId: String,
        contentConfig: ContentAnimationConfig?
    ) -> Int
}

struct LinearRevealSpeedStrategy: RevealSpeedStrategy { ... }
```

### 5.5 FragmentAnimationDriver

```swift
protocol FragmentAnimationDriver: AnyObject {
    var delegate: FragmentAnimationDriverDelegate? { get set }
    var theme: MarkdownTheme { get set }
    func applyDiff(changes: [FragmentChange], fragments: [RenderFragment], frames: [String: CGRect])
    func handleUpdate(fragmentId: String, updateResult: ContentUpdateResult)
    func handleDelete(fragmentId: String)
    func skipToEnd()
    func reset()
}

protocol FragmentAnimationDriverDelegate: AnyObject {
    func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, createAndAddViewFor fragmentId: String) -> UIView?
    func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, didAddFragmentAt index: Int)
    /// heightMode == .animationProgress 时，tick 中 displayedLength 变化后调用
    func fragmentAnimationDriver(_ driver: FragmentAnimationDriver, contentHeightNeedsUpdateFor fragmentId: String, displayedLength: Int)
}
```

### 5.6 AnimationConfiguration（协议优先，少用闭包）

```swift
/// Driver 工厂协议（替代闭包）
public protocol FragmentAnimationDriverProvider {
    func makeDriver() -> FragmentAnimationDriver
}

/// Reveal 策略工厂协议（替代闭包）
public protocol TextRevealStrategyProvider {
    func makeStrategy(for target: TextDisplayTarget) -> TextRevealStrategy
}

public struct AnimationConfiguration {
    public var animationDriverProvider: FragmentAnimationDriverProvider
    public var revealStrategyProvider: TextRevealStrategyProvider
    public var revealSpeedStrategy: RevealSpeedStrategy
    public var fragmentHeightMode: FragmentHeightMode  // fullContent / animationProgress，见 FRAGMENT_HEIGHT_REFACTOR
    // 保留：enterAnimationExecutor, baseCharsPerFrame, globalSpeedMultiplier
}

// 默认实现
struct DefaultAnimationDriverProvider: FragmentAnimationDriverProvider { func makeDriver() -> FragmentAnimationDriver { InstantAnimationDriver() } }
struct SubstringRevealStrategyProvider: TextRevealStrategyProvider { func makeStrategy(for target: TextDisplayTarget) -> TextRevealStrategy { SubstringRevealStrategy(targetView: target) } }
```

### 5.7 SimpleStreamableContent

```swift
/// 辅助协议：displayedLength=totalLength、reveal 空实现
/// 用于只需进入动画、无内容逐字的 View
protocol SimpleStreamableContent: StreamableContent {}

extension SimpleStreamableContent {
    var displayedLength: Int { totalLength }
    func reveal(upTo length: Int) {}
    func updateContent(_ content: Any) -> ContentUpdateResult { .unchanged(length: totalLength) }
}
```

---

## 六、数据流（最终态）

```
applyDiff(newResult, oldFragments)
  → changes = StreamingFragmentDiffer.diff(...)
  → renderResult = newResult
  → calculateFrames(for: fragments)
  → driver.applyDiff(changes, fragments, frames)

[InstantAnimationDriver.applyDiff]
  for fragment in fragments:
    view = delegate.createAndAddViewFor(fragmentId)
    delegate.didAddFragmentAt(index)

[StreamAnimator.applyDiff]
  更新 fragmentOrder, targetProgress
  startDisplayLinkIfNeeded()
  [tick]
    if views[id] == nil: view = delegate.createAndAddViewFor(id); didAddFragmentAt(...)
    enter + reveal（step = revealSpeedStrategy.charsPerFrame(...)）
```

---

## 七、文件变更清单

**新增**：TextDisplayTarget、FragmentAnimationDriver、InstantAnimationDriver、StreamAnimator、StreamableContent、TextRevealStrategy（含 SubstringRevealStrategy）、RevealSpeedStrategy（含 LinearRevealSpeedStrategy）、ContentChangeAnalyzer；FragmentAnimationDriverProvider、TextRevealStrategyProvider（协议，替代闭包工厂）

**修改**：AnimationConfiguration、MarkdownTextView、CodeBlockView、BlockQuoteTextView、MarkdownTableView、MarkdownContainerView

**删除**：AnimationController、AnimatableContent、AttributedTextDisplayable、TextDisplayStrategy、Strategies/ 下三个

**文档**：CUSTOM_VIEW_ANIMATION.md 或 ARCHITECTURE 章节：自定义 View 接入说明

---

*版本：2026-02-27*
