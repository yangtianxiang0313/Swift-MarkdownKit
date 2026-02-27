# Fragment 高度计算改造方案

> 动画系统改造的**前置依赖**。高度支持跟随动画进度，由对应 View 的静态方法实现，可配置。

---

## 一、目标与背景

### 1.1 现状

| 环节 | 实现 | 问题 |
|------|------|------|
| **高度来源** | Fragment.estimatedSize（Renderer 创建时计算） | 仅支持完整内容高度 |
| **布局** | Container.calculateFrames 一次算出全部 fragmentFrames | contentHeight 固定 |
| **动画期间** | View 显示 substring，frame 仍是完整高度 | 底部空白，滚动区域与实际可见不一致 |

### 1.2 目标

1. **高度模式可配置**：支持「完整高度」与「跟随动画进度」两种模式
2. **高度由 View 静态方法实现**：各 View 类型提供 `estimatedHeight(content, displayedLength, maxWidth)`，封装自身布局逻辑
3. **为动画改造铺路**：动画系统改造依赖本方案，新 animator 需在 tick 时驱动 contentHeight 更新

---

## 二、设计

### 2.1 高度模式（AnimationConfiguration）

```swift
public enum FragmentHeightMode {
    /// 始终使用完整内容高度（当前行为）
    case fullContent
    
    /// 高度跟随动画进度：已完成的 fragment 用完整高度，当前播放的 fragment 用 displayedLength 对应高度
    case animationProgress
}
```

`AnimationConfiguration` 新增：

```swift
public var fragmentHeightMode: FragmentHeightMode  // 默认 .fullContent
```

### 2.2 View 静态方法（各 View 类型实现）

每个参与流式动画的 View 类型提供**静态方法**计算高度：

```swift
// MarkdownTextView
static func estimatedHeight(
    attributedString: NSAttributedString,
    displayedLength: Int,
    maxWidth: CGFloat,
    theme: MarkdownTheme
) -> CGFloat

// BlockQuoteTextView
static func estimatedHeight(
    attributedString: NSAttributedString,
    displayedLength: Int,
    blockQuoteDepth: Int,
    maxWidth: CGFloat,
    theme: MarkdownTheme
) -> CGFloat

// CodeBlockView
static func estimatedHeight(
    codeText: String,
    displayedLength: Int,
    maxWidth: CGFloat,
    theme: MarkdownTheme
) -> CGFloat

// MarkdownTableView、ThematicBreakView 等
// displayedLength 无意义时，直接使用完整高度（displayedLength 忽略或等于 contentLength）
static func estimatedHeight(...) -> CGFloat
```

**规则**：

- `displayedLength == totalLength` 或 `displayedLength >= content.length`：等价于完整高度
- `displayedLength == 0`：可为 0 或最小行高，由 View 定义
- 实现使用 `attributedSubstring(0..<displayedLength).boundingRect` 或等价逻辑

### 2.3 Fragment 桥接（依赖倒置， protocol 优先）

遵循**依赖倒置**与**少用闭包、多用协议**：框架不因类型做分支，由用户在**创建 Fragment 时注入** `FragmentHeightProvider` 协议实现。

`FragmentViewFactory` 新增方法；Fragment 在创建时可选传入 `heightProvider`：

```swift
/// 按动画进度计算高度的提供者（协议，非闭包）
public protocol FragmentHeightProvider {
    func estimatedHeight(atDisplayedLength displayedLength: Int, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat
}

protocol FragmentViewFactory: RenderFragment {
    var estimatedSize: CGSize { get }
    
    func estimatedHeight(atDisplayedLength displayedLength: Int, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat
}

extension FragmentViewFactory {
    func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat {
        estimatedSize.height
    }
}
```

**依赖倒置设计**：

| Fragment | 实现方式 |
|----------|----------|
| **TextFragment** | init/create 时传入 `heightProvider: FragmentHeightProvider?`；TextFragment.create 根据 blockQuoteDepth 创建 `TextHeightProvider`（struct，持有 attributedString、blockQuoteDepth，实现协议并委托 View 静态方法） |
| **ViewFragment** | init 时可选传入 `heightProvider`；DefaultRenderers 创建时传入 `CodeBlockHeightProvider(content:)`、`TableHeightProvider(data:)` 等 |
| **用户自定义** | 用户定义自己的 struct 遵循 `FragmentHeightProvider`，创建 ViewFragment 时传入，无需改框架任何代码 |
| **SpacingFragment 等** | 不传 heightProvider，用协议默认 `estimatedSize.height` |

**原则**：框架零 switch，用户扩展零侵入；用 protocol 而非闭包。

### 2.4 Container 集成

**calculateFrames**（不变）：仍基于完整内容算 frame，`fragmentFrames` 存完整尺寸，用于 x、width、y 基准。

**contentHeight 计算**（按 heightMode 分支）：

- **fullContent**：与现有一致，`contentHeight = 累加 fragmentFrames 高度`
- **animationProgress**：
  - 已完成的 fragment：用 `fragmentFrames` 高度
  - 当前播放的 fragment：用 `fragment.estimatedHeight(atDisplayedLength: view.displayedLength, maxWidth:, theme:)`
  - 未创建的 fragment：不计入（懒创建下不占高度）

**更新时机**：

- fullContent：只在 applyDiff / calculateFrames 时更新
- animationProgress：每次 tick 中 displayedLength 变化时更新 contentHeight，并更新当前 fragment 的 frame.height

---

## 三、实现阶段

### Phase 1：View 静态方法

| 序号 | 任务 | 输出 | 验收 |
|-----|------|------|------|
| 1.1 | MarkdownTextView.estimatedHeight | 静态方法 | 用 attributedSubstring(0..<displayedLength).boundingRect；displayedLength=0 时合理返回值 |
| 1.2 | BlockQuoteTextView.estimatedHeight | 静态方法 | 含 indent、blockQuoteDepth |
| 1.3 | CodeBlockView.estimatedHeight | 静态方法 | 用 codeText 的 substring |
| 1.4 | MarkdownTableView.estimatedHeight | 静态方法 | displayedLength 无意义，等价完整高度 |
| 1.5 | 其它 ViewFragment 对应 View | 静态方法 | 可委托 estimatedSize 或固定高度 |

### Phase 2：FragmentViewFactory 扩展（依赖倒置， protocol）

| 序号 | 任务 | 输出 | 验收 |
|-----|------|------|------|
| 2.1 | 定义 `FragmentHeightProvider` 协议 | 新协议 | `estimatedHeight(atDisplayedLength:maxWidth:theme:) -> CGFloat` |
| 2.2 | FragmentViewFactory 增加 estimatedHeight(atDisplayedLength:maxWidth:theme:) | 协议方法 | 默认返回 estimatedSize.height |
| 2.3 | TextFragment 增加 heightProvider 可选参数 | - | create 时创建 TextHeightProvider（struct 遵循 FragmentHeightProvider）传入 init；estimatedHeight 委托给 provider |
| 2.4 | ViewFragment 增加 heightProvider 可选参数 | - | init 接受 provider；DefaultRenderers 创建时传入 CodeBlockHeightProvider、TableHeightProvider 等；无框架内部 switch |
| 2.5 | 实现 TextHeightProvider、CodeBlockHeightProvider、TableHeightProvider | - | 各 struct 遵循 FragmentHeightProvider，内部调用对应 View 静态方法 |
| 2.6 | SpacingFragment 等 | - | 不传 heightProvider，用默认实现 |

### Phase 3：配置与 Container 集成

| 序号 | 任务 | 输出 | 验收 |
|-----|------|------|------|
| 3.1 | FragmentHeightMode 枚举 | AnimationConfig 或新文件 | fullContent / animationProgress |
| 3.2 | AnimationConfiguration.fragmentHeightMode | 配置项 | 默认 .fullContent |
| 3.3 | Container contentHeight 计算分支 | MarkdownContainerView | fullContent 用现有逻辑；animationProgress 用 estimatedHeight(atDisplayedLength:) |
| 3.4 | animationProgress 时的更新入口 | - | 供 animator 在 displayedLength 变化时调用；当前可先空实现，动画改造时接入 |

### Phase 4：与动画改造的衔接点

动画改造完成后，需在此处挂接：

**Delegate 新增方法**（FragmentAnimationDriverDelegate）：

```swift
/// 当 heightMode == .animationProgress 时，animator 在 tick 中 displayedLength 变化后调用
func fragmentAnimationDriver(
    _ driver: FragmentAnimationDriver,
    contentHeightNeedsUpdateFor fragmentId: String,
    displayedLength: Int
)
```

**调用方**：StreamAnimator.tick 中，执行 `view.reveal(upTo: newLen)` 后，若 `config.fragmentHeightMode == .animationProgress`，调用上述 delegate 方法。

**实现方**：Container 重算当前 fragment 的 `estimatedHeight(atDisplayedLength:displayedLength, maxWidth:, theme:)`，更新该 fragment 的 frame.height，重算 contentHeight 并触发 `onContentHeightChanged`。

本方案先完成 Phase 1–3，Phase 4 的 delegate 方法与 animator 调用在动画改造时实现。

---

## 四、类型与接口规格

### 4.1 FragmentHeightMode

```swift
public enum FragmentHeightMode {
    case fullContent      // 始终完整高度
    case animationProgress // 跟随动画进度
}
```

### 4.2 FragmentHeightProvider 与 FragmentViewFactory

```swift
public protocol FragmentHeightProvider {
    func estimatedHeight(atDisplayedLength displayedLength: Int, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat
}

// 内置实现示例
struct TextHeightProvider: FragmentHeightProvider {
    let attributedString: NSAttributedString
    let blockQuoteDepth: Int
    func estimatedHeight(...) -> CGFloat { ... }  // 委托 MarkdownTextView / BlockQuoteTextView 静态方法
}

struct CodeBlockHeightProvider: FragmentHeightProvider {
    let content: CodeBlockContent
    func estimatedHeight(...) -> CGFloat { CodeBlockView.estimatedHeight(...) }
}

// TextFragment / ViewFragment 创建时传入 heightProvider: FragmentHeightProvider?，内部存储并委托
extension FragmentViewFactory {
    func estimatedHeight(...) -> CGFloat { estimatedSize.height }  // 默认
}
```

### 4.3 View 静态方法约定

```swift
static func estimatedHeight(
    content: ...,
    displayedLength: Int,
    maxWidth: CGFloat,
    theme: MarkdownTheme
) -> CGFloat
```

---

## 五、文件变更清单

**新增**：`FragmentHeightMode` 在 AnimationConfig.swift；`FragmentHeightProvider` 协议及 `TextHeightProvider`、`CodeBlockHeightProvider`、`TableHeightProvider` 在 FragmentViewFactory.swift

**修改**：
- MarkdownTextView、BlockQuoteTextView、CodeBlockView、MarkdownTableView：增加静态 `estimatedHeight(..., theme:)`
- FragmentViewFactory：增加 `estimatedHeight(atDisplayedLength:maxWidth:theme:)`，默认实现
- TextFragment：init/create 增加 `heightProvider: FragmentHeightProvider?`；estimatedHeight 委托给 provider
- ViewFragment：init 增加 `heightProvider: FragmentHeightProvider?`；estimatedHeight 委托给 provider
- DefaultRenderers：创建 TextFragment、ViewFragment 时传入对应 HeightProvider 实例
- AnimationConfiguration：增加 `fragmentHeightMode`
- MarkdownContainerView：contentHeight 计算按 `fragmentHeightMode` 分支，调用时传入 theme；预留 animationProgress 更新入口

---

## 六、依赖关系

```
FRAGMENT_HEIGHT_REFACTOR（本方案）
        │
        │ 前置依赖
        ▼
ANIMATION_IMPLEMENTATION_SPEC（动画改造）
```

动画改造在实现 StreamAnimator、delegate 时，需调用本方案提供的 `estimatedHeight(atDisplayedLength:)` 及 contentHeight 更新入口。

---

*版本：2026-02-27*
