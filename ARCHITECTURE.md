# XHSMarkdownKit 理想架构

---

## 一、全局视图

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│   任意输入                                                            │
│       │                                                              │
│       ▼                                                              │
│   ┌─────────────────────────────────────┐                            │
│   │  数据管线 (纯函数，无状态)             │                            │
│   │  Input → ... → [RenderFragment]     │ ← 可整体替换               │
│   │                                     │   Markdown 是默认实现       │
│   └────────────────┬────────────────────┘                            │
│                    │                                                 │
│                    │ [RenderFragment]                                 │
│                    ▼                                                 │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │  MarkdownContainerView : FragmentContaining                  │   │
│   │                                                              │   │
│   │  ┌──────────┐    ┌───────────────────────────────────────┐   │   │
│   │  │  Differ   │───→│  AnimationDriver                      │   │   │
│   │  │(协议,可替换)│    │  (统管 Reconcile + Layout + Animate)  │   │   │
│   │  └──────────┘    └───────────────────────────────────────┘   │   │
│   │                                                              │   │
│   │  ┌────────────────────────────────┐                          │   │
│   │  │  ViewPool (复用池，可跨嵌套共享) │                          │   │
│   │  └────────────────────────────────┘                          │   │
│   │                         │                                    │   │
│   │                         ▼                                    │   │
│   │                    UIView 层级（支持递归嵌套）                 │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Core/Markdown 分层**：

```
Core 层（与 Markdown 无关）           Markdown 层（默认实现）
─────────────────────────           ──────────────────────
RenderFragment                      MarkdownParser
FragmentViewFactory                 MarkdownNode
FragmentContaining                  NodeRenderer / RendererRegistry
FragmentDiffing                     ViewStrategy 协议族
AnimationDriver                     BlockSpacingResolving
HeightEstimatable                   MarkdownTheme
StreamableContent                   RenderContext / ContextKey
ViewTransition                      FragmentOptimizer
FragmentNodeType (通用 struct)       MarkdownNodeType (具体 enum/extension)
FragmentContext (通用 KV 容器)       具体 ContextKey (blockQuoteDepth 等)
```

Core 层**零 Markdown 引用**——不 import MarkdownTheme、不引用 MarkdownNodeType。

---

## 二、数据管线

纯函数，无状态，不感知流式/动画/UI。

签名：

```swift
func render(_ text: String, maxWidth: CGFloat, theme: MarkdownTheme, stateStore: FragmentStateStore?) -> [RenderFragment]
```

所有影响输出的因素都必须作为显式参数传入：
- `text`：原始 Markdown 文本
- `maxWidth`：布局宽度（ViewStrategy 用于在 Render 阶段将 theme 解析为具体值）
- `theme`：Markdown 主题（仅数据管线内部使用，不传递给 Core 协议）
- `stateStore`：外部状态（如代码块复制状态），影响 Renderer 产出的内容

### 2.1 Parse

```
MarkdownParser 协议
parse(_ text: String) -> MarkdownNode

默认: XYMarkdownParser (XYMarkdown/cmark)
可替换: 任意实现
```

输出 `MarkdownNode`（自有 AST 协议层级），与具体 Parser 实现解耦。用户可定义子协议、创建自定义节点 struct，标准和自定义节点可混合存在于同一棵树中。

### 2.2 Rewrite（可选）

```
RewriterPipeline
rewrite(_ node: MarkdownNode) -> MarkdownNode

用户注入 Rewriter 列表
库不内置任何具体 Rewriter（如 RichLinkRewriter 属业务逻辑，应在宿主 App 中实现）
```

### 2.3 Render

```
RendererRegistry 分发：每个 MarkdownNodeType → NodeRenderer
优先级: 自定义 > 默认 > 通配 > Fallback
```

**NodeRenderer 职责**：内容提取 + 参数解析

- 从 AST 提取 content data（纯数据）
- 调用 ViewStrategy，传入 content + context + theme，Strategy 解析为**具体渲染参数**并写入 Fragment
- Fragment 在创建时即包含所有渲染所需的具体值，后续 configure / estimatedHeight 不再需要 theme
- content data 是 Renderer 和 ViewStrategy 之间的契约，在 ViewFragment 中类型擦除为 `Any`，通过 `ViewFragment.typed<V,C>` 泛型保证类型安全

```
content data 示例:
  Paragraph  → NSAttributedString
  CodeBlock  → CodeBlockContent(code, language, fragmentId)
  Table      → TableData(headers, rows, alignments)
  Image      → ImageContent(source, title, alt)
  自定义     → 用户自定义 struct
```

**Container 节点**（Document, List, BlockQuote）：通过 ChildRenderer 递归渲染子节点，产出 ContainerFragment（持有 childFragments）。ContainerFragment 的 View 本身是嵌套的 FragmentContaining 实现（详见 3.9 嵌套容器）。

**Leaf 节点**（Paragraph, Heading, CodeBlock, Table...）：直接产出 ViewFragment。

**上下文来源**：Renderer 不依赖兄弟 Fragment。所有上下文信息来自：
- AST 树结构（node.children、parent 传入的 index 等）
- RenderContext 累积状态（depth、indent、listIndex 等）
- 父 Renderer 通过 ContextKey 注入子节点所需信息

**Theme 解析时机**：theme 在 Render 阶段由 ViewStrategy 一次性解析为具体值（CGFloat、UIColor、UIFont 等），写入 Fragment。此后 Core 层的 configure、estimatedHeight 均不再接触 theme。若 theme 变更，整条管线重新执行，Fragment 重建。

### 2.4 Optimize

顺序：Merge → Filter → SetSpacing

**Merge**：Fragment 通过 `MergeableFragment` 协议自声明 `canMerge` 和 `merged`。合并后的 Fragment ID 取首个（保持 diff 稳定性）。合并后的 Fragment 之间的内部间距（如段落间距）由 `merged()` 嵌入 content（例如写入 NSAttributedString 的 paragraphSpacing），`merged()` 接收 theme 用于计算间距值。

**Filter**：过滤空 Fragment。

**SetSpacing**：遍历 Fragment 数组，用 `BlockSpacingResolving` 根据 (current, next) 节点类型设置 `fragment.spacingAfter`。这里的 spacingAfter 是 Fragment 间的外部间距，与 Merge 阶段的内部间距互不干涉。

**为什么不用 SpacingFragment**：

间距不是内容，是两个 Fragment 之间的关系。给它赋予 Fragment 身份（fragmentId、View 生命周期、diff 匹配）是概念错位。具体问题：

| 问题 | 说明 |
|---|---|
| diff 噪声 | SpacingFragment 的 ID 从邻居派生，邻居变则它变，产生无意义的 diff |
| merge 困难 | 跨 SpacingFragment 的相邻 Fragment 无法自然合并 |
| TypingDriver 分支 | 需要特殊处理（跳过？创建空 View？），违反"不做类型分支"原则 |
| 数组膨胀 | Fragment 数量翻倍，diff 计算量增加 |

spacingAfter 作为 Fragment 属性，不增加数组元素，不影响 diff，不需要 View，布局时一行累加即可。

---

## 三、视图管线

### 3.1 Diff

```
[RenderFragment] new     [RenderFragment] old (上一次快照)
        │                        │
        └────────┬───────────────┘
                 ▼
          FragmentDiffing 协议
          diff(old, new) → [FragmentChange]
```

`FragmentDiffing` 是纯函数，与 AnimationDriver 无关。

**FragmentChange**：

```
insert(fragment, index)
remove(fragmentId, index)
update(old, new, childChanges?)     ← childChanges 用于嵌套容器
move(fragmentId, from, to)
```

**递归 diff**：对于 ContainerFragment，diff 会递归比较其 `childFragments`，结果挂在 `update` 变更的 `childChanges` 字段上。AnimationDriver 消费 `childChanges` 时传递给子容器 View 处理。

### 3.2 AnimationDriver

AnimationDriver 是 diff 之后的唯一执行者，统管 View 创建、内容配置、布局、动画。

```swift
protocol AnimationDriver {
    func apply(changes: [FragmentChange], fragments: [RenderFragment], to container: FragmentContaining)
    func finishAll()
}
```

AnimationDriver 维护三组状态：
- **targetFragments**：最新完整快照（最终目标）
- **displayedFragments**：当前屏幕上实际显示的 Fragment 子集
- **pendingQueue**：在 target 中但尚未创建 View 的 Fragment

### 3.3 InstantDriver

默认实现，收到 changes 后立即到位：

```
insert  → dequeueView + configure(全内容) + layout(最终高度)
update  → configure(新内容) + relayout
remove  → recycleView
move    → 调整 View 顺序 + relayout
```

### 3.4 TypingDriver

逐字插值动画。核心逻辑：

```
收到 changes:
  更新 targetState
  新 fragment 加入 pendingQueue

每个 DisplayLink tick:
  当前 fragment 已完成？
    → 从 pendingQueue 取下一个
    → dequeueView + configure
    → 加入 displayedFragments
  displayedLength += step
  view.reveal(upTo: displayedLength)
  height = view.estimatedHeight(atDisplayedLength: displayedLength, maxWidth: maxWidth)
  relayout
  displayedLength == totalContentLength → 完成，取下一个
```

**TypingDriver 处理动画期间的 Fragment 级变更**：

TypingDriver 不是"播放动画序列"，而是"持续把 displayState 推进到 targetState"。当新 diff 到达时，targetState 可能发生 insert/remove/move，driver 按以下规则处理：

```
1. 已显示且在新 target 中未变       → 保持不动
2. 已显示且在新 target 中 content 变了 → 更新 content，displayedLength 保持当前值
                                       继续向新 totalContentLength 前进
3. 已显示但在新 target 中不存在了     → 立即移除 View，回收到 pool
   (remove)                           正在动画中的 Fragment 直接中止动画
4. 新 target 中新增的 Fragment
   ├── 插入位置 ≤ 当前动画进度        → 立即创建 View，以最终状态显示（它在"过去"）
   └── 插入位置 > 当前动画进度        → 加入 pendingQueue，等动画轮到它
5. Fragment 位置变了 (move)           → 调整 View 在父视图中的顺序，relayout
                                       不影响 displayedLength

全部处理完 → relayout 所有 View
继续 tick 循环，从当前位置向新 targetState 前进
```

**内容截短处理**：若流式更新导致 content 变短（displayedLength > newTotalContentLength），displayedLength 立即回退到新长度，不做反向动画。

### 3.5 高度计算

高度知识属于 View，不属于 Fragment。所有参与管线的 View **必须**实现 `HeightEstimatable`：

```swift
protocol HeightEstimatable {
    func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat
}
```

- AnimationDriver 通过此协议计算每个 View 的当前高度
- 不接受兜底——未实现 HeightEstimatable 的 View 不能参与管线
- Fragment 不携带 heightProvider
- **无 theme 参数**：View 在 `configure` 时已从 ViewStrategy 接收所有具体渲染参数（font、lineSpacing 等），内部已持有计算高度所需的全部信息

工作流：

```
1. fragment.makeView()       → 创建 View
2. fragment.configure(view)  → View 拿到完整 content（含已解析的具体值）
3. view.estimatedHeight(atDisplayedLength: 0, maxWidth: w)     → 初始高度
4. 每个 tick：view.estimatedHeight(atDisplayedLength: len, maxWidth: w) → 当前高度
```

### 3.6 间距与布局

spacingAfter 参与布局的规则：**最后一个已显示 Fragment 不加 spacingAfter**。

```swift
var y: CGFloat = 0
for (i, fragment) in displayedFragments.enumerated() {
    let view = viewForFragment(fragment)
    view.frame.origin.y = y
    y += view.bounds.height
    if i < displayedFragments.count - 1 {
        y += fragment.spacingAfter
    }
}
```

这确保 TypingDriver 在逐个 reveal Fragment 时，尾部不会出现多余间距。当后续 Fragment 出现后，前一个 Fragment 的 spacingAfter 自然生效。

### 3.7 渐进展示

**Fragment 侧**：`ProgressivelyRevealable`（opt-in），声明可渐进展示的内容总长度：

```swift
protocol ProgressivelyRevealable: RenderFragment {
    var totalContentLength: Int { get }
}
```

| Fragment 类型 | totalContentLength | 动画效果 |
|---|---|---|
| 段落/标题 | attributedString.length | 逐字出现 |
| 代码块 | code.length | 逐字出现 |
| 图片/表格/分割线 | 1 | 一步到位 |
| 自定义 | 用户决定 | 用户决定 |

未实现 ProgressivelyRevealable → TypingDriver 视为 instant（创建后立即完整显示）。

**View 侧**：`StreamableContent`（opt-in），支持部分内容展示：

```swift
protocol StreamableContent {
    func reveal(upTo length: Int)
}
```

View 实现了 `reveal(upTo:)` → 支持渐进展示；未实现 → configure 后直接全部显示。

### 3.8 View 过渡动画

View 级别的入场/离场效果（如 fade-in、slide-in），与 content 级别的渐进展示（逐字出现）是独立的两层动画，可叠加。

**ViewTransition 协议**（Core 层）：

```swift
protocol ViewTransition {
    func animateIn(view: UIView, completion: @escaping () -> Void)
    func animateOut(view: UIView, completion: @escaping () -> Void)
}
```

**Fragment 可选声明过渡偏好**（Core 层 opt-in）：

```swift
protocol TransitionPreferring: RenderFragment {
    var enterTransition: ViewTransition? { get }
    var exitTransition: ViewTransition? { get }
}
```

**内置实现**（Core 层）：

```swift
struct FadeTransition: ViewTransition { ... }
struct NoTransition: ViewTransition { ... }
```

**谁设置 Transition**：ViewStrategy（Markdown 层）。Strategy 知道 View 类型，最适合决定过渡效果。Renderer 创建 Fragment 时从 Strategy 获取 transition 写入 Fragment。

**AnimationDriver 执行方式**：

AnimationDriver 通过 opt-in 协议检查获取 transition。这是**能力发现**（检查协议 conformance），不是类型分支（`as? ConcreteType`）：

```
insert:
  dequeueView → configure
  if fragment is TransitionPreferring, let enter = fragment.enterTransition
      enter.animateIn(view, completion: { ... })
  else
      Driver 自身的默认 transition

remove:
  if fragment is TransitionPreferring, let exit = fragment.exitTransition
      exit.animateOut(view, completion: { recycle view })
  else
      Driver 自身的默认 transition → recycle
```

**与 TypingDriver 的叠加**：

```
TypingDriver insert:
  1. 创建 View
  2. enterTransition.animateIn（View 级 enter，如 fade-in）
  3. 同时开始 reveal(upTo: 0→target)（content 级 reveal，如逐字出现）
两层独立执行、可叠加
```

### 3.9 嵌套容器

ContainerFragment 的 View 本身实现 FragmentContaining，整套视图管线递归：

```
MarkdownContainerView : FragmentContaining
│
├── LeafView (段落)
├── LeafView (标题)
├── BlockQuoteContainerView : FragmentContaining    ← 递归
│   ├── LeafView (引用内段落)
│   ├── LeafView (引用内段落)
│   └── BlockQuoteContainerView : FragmentContaining
│       └── LeafView (段落)
├── LeafView (段落)
```

**工作流**：

AnimationDriver 不做类型判断。Container 和 Leaf 都走同一个 `fragment.configure(view)` 调用。ContainerFragment 的 configure 内部自行触发子管线：

```
AnimationDriver 对所有 fragment 统一调用:
  fragment.configure(view)
    │
    ├── LeafFragment: 配置 View 内容，结束
    │
    └── ContainerFragment:
          1. 配置装饰（竖线颜色、边距等，具体值已在 Render 阶段解析）
          2. containerView.update(childFragments)
             └── 子容器内部：子 diff → 子 AnimationDriver.apply → 递归
```

**共享机制**：
- ViewPool：整棵树共享同一个 pool（通过引用传递）
- AnimationDriver：默认继承父容器的 driver，用户可覆盖
- Differ：默认继承父容器的 differ

**高度递归**：容器 View 实现 HeightEstimatable，高度 = Σ 子 View 高度 + Σ spacingAfter + 装饰边距

---

## 四、Renderer → ViewStrategy → View 三层分离

```
┌─ Renderer (管线层) ─────────────────────────────────────────────────┐
│  AST → content data                                                 │
│  从 AST 提取纯数据                                                   │
│  不知道 View 的存在                                                   │
│  不依赖兄弟 Fragment（所有上下文从 AST + RenderContext 获取）           │
└────────────────────────┬────────────────────────────────────────────┘
                         │ content data + RenderContext
                         ▼
┌─ ViewStrategy (桥接层，Markdown 层) ────────────────────────────────┐
│  content + context + theme → 具体渲染参数                             │
│  知道 RenderContext（blockQuoteDepth, indent 等）                     │
│  知道 MarkdownTheme                                                  │
│  知道 View 类型                                                      │
│  将 context + theme 解析为 View 需要的具体值（leftInset, lineColor）   │
│  决定 View 的过渡动画（enterTransition, exitTransition）              │
│  解析结果写入 Fragment，Fragment 自此自包含                            │
└────────────────────────┬────────────────────────────────────────────┘
                         │ 具体值 (CGFloat, UIColor, UIFont, ViewTransition, ...)
                         ▼
┌─ View (纯 UI 层) ──────────────────────────────────────────────────┐
│  只接收具体的渲染参数                                                 │
│  不知道 RenderContext、MarkdownTheme、AST、管线的存在                  │
│  独立可测试：传具体值即可测试，无需构造管线对象                           │
│  必须实现 HeightEstimatable（无 theme 参数）                          │
└────────────────────────────────────────────────────────────────────┘
```

**Theme 解析边界**：

```
theme 存在的范围:
  MarkdownRenderPipeline.render() 内部
    Parse → Rewrite → Render(ViewStrategy 消费 theme) → Optimize(SetSpacing 消费 theme)

theme 不存在的范围（Core 层）:
  FragmentViewFactory.configure(_ view: UIView)     ← 无 theme
  HeightEstimatable.estimatedHeight(...)             ← 无 theme
  AnimationDriver.apply(...)                         ← 无 theme
  FragmentDiffing.diff(...)                          ← 无 theme
```

替换粒度：

```
├── 只换 View:       注入自定义 ViewStrategy，Renderer 不动
├── 只换渲染逻辑:    注册自定义 Renderer，复用默认 Strategy
└── 两者都换:        注入 Strategy + 注册 Renderer
```

---

## 五、流式 × 动画：正交组合

```
流式 = 输入侧行为（谁调用管线、调几次）
动画 = 输出侧策略（AnimationDriver 的实现）
两者正交，互不感知。

         ┌──────────────────┬──────────────────────────┐
         │  InstantDriver    │  TypingDriver             │
┌────────┼──────────────────┼──────────────────────────┤
│ 单次   │ 立即完整显示      │ 打字机效果逐字出现         │
│ update  │                  │                          │
├────────┼──────────────────┼──────────────────────────┤
│ 多次   │ 每次 diff 后      │ 每次 diff 更新 target,   │
│ update  │ 立即刷新          │ 动画平滑插值到目标        │
│ (流式) │                  │                          │
└────────┴──────────────────┴──────────────────────────┘
```

**多次 diff 的动画合并**：TypingDriver 永远朝最新 targetState 前进。
- 新 diff 到达 → 更新 target，从当前 displayedLength 继续向前
- 不回放旧动画，不等旧动画播完再处理新 diff
- 中途出现 fragment 级 insert/remove/move → 按 3.4 节规则处理

**增量数据管线不做**：Markdown 解析是上下文敏感的，增量解析复杂度高、收益低。瓶颈在 View 层而非管线。全量 render + diff 是最优性价比方案。

---

## 六、状态管理：FragmentStateStore

```
stateStore 持有跨 render 周期的外部状态

key = 内容身份（不是位置路径）
  代码块: hash(code) + language
  用户自定义: Renderer 决定

数据流:
  Renderer 渲染时读取:
    context.stateStore.get(key: stateKey, as: CodeBlockState.self)
    → 决定 Fragment 内容（如复制按钮显示"已复制"还是"复制"）

  View 通过事件上报修改:
    delegate.containerView(self, didReceiveEvent: .codeCopied(stateKey))
    → ContainerView 监听 → 更新 stateStore → 触发重新 render

  跨 render 周期保持，不随 Fragment 重建丢失
```

---

## 七、协议总览

### 7.1 Fragment 协议

```
RenderFragment (Core)                    基础：fragmentId + nodeType(FragmentNodeType) + spacingAfter
├── FragmentViewFactory (Core)           可生产 View：reuseId + makeView + configure(_ view)
│   ├── LeafFragment (Core)              叶子（无子节点）
│   └── ContainerFragment (Core)        容器（持有 childFragments）
├── ProgressivelyRevealable (Core)      声明 totalContentLength（opt-in）
├── TransitionPreferring (Core)         声明 enterTransition / exitTransition（opt-in）
├── MergeableFragment (Core)             声明合并能力（opt-in）
└── AttributedStringProviding (Core)    声明可提供 NSAttributedString（opt-in，仅文本类 Fragment conform）
```

**注意**：`AttributedStringProviding` 是独立 opt-in 协议，ViewFragment 不无条件 conform。只有 content 为 NSAttributedString 的 Fragment 才 conform（如文本段落、标题）。图片、表格等 Fragment 不 conform。

### 7.2 视图层协议

```
FragmentContaining (Core)                容器核心能力
├── update(_ fragments:)                 接收新快照
├── dequeueView / recycleView            复用池操作
├── differ: FragmentDiffing              可注入 diff 算法
└── animationDriver: AnimationDriver     可注入动画策略

FragmentDiffing (Core)                   diff(old, new) → [FragmentChange]
                                         递归处理 ContainerFragment.childFragments
                                         update 携带 childChanges

AnimationDriver (Core)                   apply(changes, fragments, container) + finishAll()
├── InstantDriver (Core)                 默认，立即到位
├── TypingDriver (Core)                  逐字插值，维护 target/displayed/pending 状态
└── 用户自定义                            任意动画

HeightEstimatable (Core)                 View 必须实现（无兜底）
                                         estimatedHeight(atDisplayedLength:maxWidth:)
                                         无 theme 参数——View 已从 configure 获得所有具体值

StreamableContent (Core)                 View opt-in：reveal(upTo:)

ViewTransition (Core)                    animateIn(view, completion) + animateOut(view, completion)
├── FadeTransition (Core)                默认 fade 效果
├── NoTransition (Core)                  无动画
└── 用户自定义                            任意过渡

MarkdownContainerViewDelegate (Markdown) 事件回调（协议，非闭包）
├── didChangeContentHeight               高度变化
├── didCompleteAnimation                 动画完成
└── didReceiveEvent                      View 事件（如代码复制）
```

### 7.3 数据管线协议（Markdown 层）

```
MarkdownParser                           parse(text) → MarkdownNode
MarkdownNode                             nodeType + children（协议层级，完全可扩展）

NodeRenderer                             render(node, context, childRenderer) → [Fragment]
└── LeafNodeRenderer                     renderLeaf(node, context) → [Fragment]

RendererRegistry                         nodeType → NodeRenderer 映射
                                         优先级: 自定义 > 默认 > 通配 > Fallback

ViewStrategy 协议族                       桥接 context + theme → 具体渲染参数
├── TextViewStrategy                     段落、标题、列表项
├── CodeBlockViewStrategy                代码块
└── TableViewStrategy / ImageViewStrategy / ThematicBreakViewStrategy

BlockSpacingResolving                    spacing(after:before:theme:) → CGFloat
MergeableFragment                        canMerge + merged(with:theme:)
RewriterPipeline                         AST 级改写管道（库不内置具体 Rewriter）
```

---

## 八、核心类型

### 8.1 FragmentNodeType（Core）

通用节点类型标识，Core 层不含任何 Markdown 语义：

```swift
struct FragmentNodeType: Hashable, RawRepresentable {
    let rawValue: String
}
```

Markdown 层通过 extension 定义具体类型：

```swift
extension FragmentNodeType {
    static let paragraph = FragmentNodeType(rawValue: "paragraph")
    static let heading1 = FragmentNodeType(rawValue: "heading.1")
    static let heading2 = FragmentNodeType(rawValue: "heading.2")
    // ...heading3-6
    static let codeBlock = FragmentNodeType(rawValue: "codeBlock")
    static let table = FragmentNodeType(rawValue: "table")
    static let thematicBreak = FragmentNodeType(rawValue: "thematicBreak")
    static let image = FragmentNodeType(rawValue: "image")
    static let orderedList = FragmentNodeType(rawValue: "list.ordered")
    static let unorderedList = FragmentNodeType(rawValue: "list.unordered")
    static let listItem = FragmentNodeType(rawValue: "listItem")
    static let blockQuote = FragmentNodeType(rawValue: "blockQuote")
    static let document = FragmentNodeType(rawValue: "document")
}
```

用户扩展：

```swift
extension FragmentNodeType {
    static let pollCard = FragmentNodeType(rawValue: "custom.pollCard")
    static let collapsible = FragmentNodeType(rawValue: "custom.collapsible")
}
```

### 8.2 FragmentContext（Core）

通用 key-value 容器，Core 层不含任何 Markdown 字段：

```swift
protocol ContextKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

struct FragmentContext {
    subscript<K: ContextKey>(key: K.Type) -> K.Value { get }
}
```

Markdown 层定义具体 key：

```swift
enum BlockQuoteDepthKey: ContextKey {
    static let defaultValue: Int = 0
}

enum IndentKey: ContextKey {
    static let defaultValue: CGFloat = 0
}

enum ListItemIndexKey: ContextKey {
    static let defaultValue: Int? = nil
}
```

### 8.3 RenderContext（Markdown 层）

不可变，每次修改返回新实例（Environment 模式）：

```
RenderContext
├── theme: MarkdownTheme
├── maxWidth: CGFloat
├── indent: CGFloat                       累积缩进
├── blockQuoteDepth: Int                  引用块嵌套深度
├── listDepth: Int                        列表嵌套深度
├── pathPrefix: String                    Fragment ID 路径
├── stateStore: FragmentStateStore
├── [TextViewStrategyKey]: TextViewStrategy
├── [CodeBlockViewStrategyKey]: CodeBlockViewStrategy
├── [SpacingResolverKey]: BlockSpacingResolving
└── [自定义 ContextKey]: 任意扩展

父 Renderer 通过 ContextKey 向子节点注入信息：
  ListRenderer → setting(ListItemIndexKey, to: index)
  子 Renderer 读取 context[ListItemIndexKey.self]
  无需横向看兄弟 Fragment
```

### 8.4 ViewFragment

```
ViewFragment : LeafFragment
├── fragmentId: String
├── nodeType: FragmentNodeType            ← Core 通用类型，非 MarkdownNodeType
├── reuseIdentifier: ReuseIdentifier (struct, 开放扩展)
├── spacingAfter: CGFloat                 由 Optimize.SetSpacing 设置
├── context: FragmentContext              通用 KV 上下文快照
├── content: Any                          类型擦除的 content data
├── enterTransition: ViewTransition?      由 ViewStrategy 设置
├── exitTransition: ViewTransition?       由 ViewStrategy 设置
├── makeView() → UIView
└── configure(_ view: UIView)             ← 无 theme 参数

不携带 heightProvider / estimatedSize — 高度由 View 的 HeightEstimatable 计算

条件性 conform:
├── AttributedStringProviding             仅当 content 为 NSAttributedString 时
├── ProgressivelyRevealable              由创建者决定是否设置 totalContentLength
└── TransitionPreferring                  由 ViewStrategy 决定是否设置 transition
```

### 8.5 ReuseIdentifier

```
struct ReuseIdentifier: Hashable, RawRepresentable
├── .textView / .blockQuoteText / .blockQuoteContainer
├── .codeBlockView / .markdownTableView
├── .thematicBreakView / .markdownImageView
└── 用户通过 extension 自由扩展
```

### 8.6 FragmentChange

```
enum FragmentChange
├── insert(fragment: RenderFragment, at: Int)
├── remove(fragmentId: String, at: Int)
├── update(old: RenderFragment, new: RenderFragment, childChanges: [FragmentChange]?)
└── move(fragmentId: String, from: Int, to: Int)
```

---

## 九、MarkdownContainerView

```
MarkdownContainerView : UIView, FragmentContaining
│
├── FragmentContaining 实现（Core 能力）
│   ├── differ: FragmentDiffing
│   ├── animationDriver: AnimationDriver
│   ├── currentFragments: [RenderFragment]
│   ├── update(_ fragments: [RenderFragment])
│   ├── dequeueView(reuseIdentifier:factory:) → UIView
│   └── recycleView(_:reuseIdentifier:)
│
├── Markdown 数据层
│   ├── pipeline: MarkdownRenderPipeline
│   │   ├── parser: MarkdownParser
│   │   ├── rewriterPipeline: RewriterPipeline?
│   │   ├── rendererRegistry: RendererRegistry
│   │   └── spacingResolver: BlockSpacingResolving
│   └── theme: MarkdownTheme
│
├── 事件回调（delegate 协议，非闭包）
│   ├── weak var delegate: MarkdownContainerViewDelegate?
│   ├── didChangeContentHeight
│   ├── didCompleteAnimation
│   └── didReceiveEvent
│
├── 便捷 API
│   ├── setText(_ text: String)
│   ├── appendText(_ chunk: String)       内部 preclose + render + update
│   ├── skipAnimation()
│   └── clear()
│
└── 内部
    ├── ViewPool (复用池，与嵌套 ContainerView 共享)
    ├── FragmentStateStore (跨 render 外部状态，key = 内容身份)
    └── MarkdownPreprocessor (流式预处理)
```

---

## 十、新增节点全流程

以新增「可折叠区域」为例，全流程零框架修改：

```
步骤                 用户操作                          框架修改
──────────────────────────────────────────────────────────────
1. NodeType        extension FragmentNodeType 添加静态值  无
2. Parse           提供 Rewriter 或自定义 Parser        无
3. Renderer        实现 NodeRenderer                   无
4. ViewStrategy    实现自定义 Strategy（设置过渡动画等）   无
5. View            创建 UIView + 实现 HeightEstimatable 无
6. 注册            registry.register(renderer, for:)    无
7. 间距            用默认值 或 resolver.register(...)    无
```

---

## 十一、目录结构

```
Sources/XHSMarkdownKit/
│
├── Core/                                    ← 框架核心（零 Markdown 引用）
│   ├── Protocols/
│   │   ├── RenderFragment.swift             fragmentId + nodeType(FragmentNodeType) + spacingAfter
│   │   ├── FragmentViewFactory.swift         makeView + configure(_ view)，无 theme
│   │   ├── FragmentContaining.swift          容器核心协议
│   │   ├── FragmentDiffing.swift             diff 协议
│   │   ├── AnimationDriver.swift             统管 Reconcile+Layout+Animate
│   │   ├── HeightEstimatable.swift           estimatedHeight(atDisplayedLength:maxWidth:)，无 theme
│   │   ├── StreamableContent.swift           reveal(upTo:)（opt-in）
│   │   ├── ProgressivelyRevealable.swift     totalContentLength（opt-in）
│   │   ├── TransitionPreferring.swift        enterTransition / exitTransition（opt-in）
│   │   ├── ViewTransition.swift              animateIn / animateOut
│   │   ├── AttributedStringProviding.swift   opt-in，仅文本类 Fragment conform
│   │   ├── MergeableFragment.swift           合并协议（opt-in）
│   │   └── ContextKey.swift                  通用 ContextKey 协议
│   ├── Types/
│   │   ├── ViewFragment.swift                通用 LeafFragment 实现
│   │   ├── FragmentNodeType.swift            struct（通用，开放扩展）
│   │   ├── ReuseIdentifier.swift             struct（开放扩展）
│   │   ├── FragmentContext.swift              通用 KV 容器（无 Markdown 字段）
│   │   └── FragmentChange.swift              diff 变更类型（含递归 childChanges）
│   ├── Animation/
│   │   ├── InstantDriver.swift               默认：立即到位
│   │   ├── TypingDriver.swift                逐字插值
│   │   ├── FadeTransition.swift              默认 fade 过渡
│   │   └── NoTransition.swift                无过渡动画
│   ├── Diff/
│   │   └── DefaultFragmentDiffer.swift       默认 diff 实现（递归）
│   └── ViewPool.swift                        View 复用池
│
├── Markdown/                                ← Markdown 默认实现（可整体替换）
│   ├── Pipeline/
│   │   ├── MarkdownRenderPipeline.swift      String → [RenderFragment]
│   │   └── FragmentOptimizer.swift           Merge + Filter + SetSpacing
│   ├── Parser/
│   │   ├── MarkdownParser.swift              协议
│   │   ├── MarkdownNode.swift                自有 AST 协议层
│   │   └── XYMarkdown/
│   │       ├── XYMarkdownParser.swift
│   │       └── XYNodeAdapters.swift
│   ├── Renderer/
│   │   ├── NodeRenderer.swift
│   │   ├── RendererRegistry.swift
│   │   ├── InlineRenderer.swift
│   │   └── Defaults/                        每个节点类型一个文件
│   ├── ViewStrategy/
│   │   ├── TextViewStrategy.swift            协议 + Default（theme 在此解析为具体值）
│   │   ├── CodeBlockViewStrategy.swift
│   │   ├── TableViewStrategy.swift
│   │   ├── ImageViewStrategy.swift
│   │   └── ThematicBreakViewStrategy.swift
│   ├── Spacing/
│   │   └── DefaultBlockSpacingResolver.swift
│   ├── Rewriter/
│   │   └── RewriterPipeline.swift            库不内置具体 Rewriter
│   ├── Streaming/
│   │   ├── MarkdownPreprocessor.swift
│   │   └── StreamingTextBuffer.swift
│   ├── Context/
│   │   ├── RenderContext.swift               Markdown 层上下文（含 theme）
│   │   └── MarkdownContextKeys.swift         blockQuoteDepth, indent 等具体 key
│   ├── Types/
│   │   └── MarkdownNodeTypes.swift           extension FragmentNodeType 的 Markdown 具体值
│   ├── Theme/
│   │   └── MarkdownTheme.swift
│   ├── State/
│   │   ├── FragmentStateStore.swift          key = 内容身份
│   │   └── FragmentEvent.swift
│   ├── Delegate/
│   │   └── MarkdownContainerViewDelegate.swift  事件回调协议
│   └── Views/                               全部实现 HeightEstimatable
│       ├── MarkdownTextView.swift
│       ├── BlockQuoteTextView.swift
│       ├── BlockQuoteContainerView.swift     实现 FragmentContaining（递归容器）
│       ├── CodeBlockView.swift
│       ├── MarkdownTableView.swift
│       ├── ThematicBreakView.swift
│       └── MarkdownImageView.swift
│
├── Public/
│   ├── MarkdownContainerView.swift          实现 FragmentContaining + delegate + 便捷 API
│   └── MarkdownKit.swift                    工厂方法
│
└── Extensions/
    ├── UIFont+Traits.swift
    └── NSAttributedString+Markdown.swift
```
