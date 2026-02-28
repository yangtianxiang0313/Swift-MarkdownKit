# XHSMarkdownKit 重构方案

> 目标：从现有代码一步到位重写为 ARCHITECTURE.md 描述的理想架构。
> 无用户、无兼容需求、可破坏性更新。

---

## 一、现有代码 vs 理想架构：差异总览

```
现有代码 (65 文件, 118 类型)                    理想架构
──────────────────────────────                  ──────────
文件结构:
  Animation/ (12 文件)                          Core/Animation/ (4 文件)
  Core/ (11 文件)                               Core/Protocols/ (13 文件)
  Engine/ (5 文件)                              Core/Types/ (5 文件)
  Extensions/ (3 文件)                          Core/Diff/ (1 文件)
  Fragments/ (4 文件)                           Core/ViewPool.swift
  Protocols/ (5 文件)                           Markdown/Pipeline/ (2 文件)
  Public/ (3 文件)                              Markdown/Parser/ (4 文件)
  Rewriter/ (2 文件)                            Markdown/Renderer/ (4+N 文件)
  State/ (4 文件)                               Markdown/ViewStrategy/ (5 文件)
  Streaming/ (4 文件)                           Markdown/Spacing/ (1 文件)
  Theme/ (1 文件)                               Markdown/Rewriter/ (1 文件)
  Views/ (6 文件)                               Markdown/Streaming/ (2 文件)
                                                Markdown/Context/ (2 文件)
                                                Markdown/Types/ (1 文件)
                                                Markdown/Theme/ (1 文件)
                                                Markdown/State/ (3 文件)
                                                Markdown/Delegate/ (1 文件)
                                                Markdown/Views/ (7 文件)
                                                Public/ (2 文件)
                                                Extensions/ (2 文件)

关键差异:
  MarkdownNodeType enum                →  FragmentNodeType struct (Core)
  ReuseIdentifier enum                 →  ReuseIdentifier struct (Core)
  FragmentContext 硬编码字段             →  FragmentContext 通用 KV 容器 (Core)
  configure(view, theme)               →  configure(_ view) 无 theme
  estimatedHeight(..., theme)          →  estimatedHeight(...) 无 theme
  SpacingFragment                      →  删除，改用 spacingAfter
  FragmentHeightProvider               →  HeightEstimatable (View 实现)
  StreamAnimator (class)               →  TypingDriver (struct/class)
  FragmentAnimationDriver (protocol)   →  AnimationDriver (protocol, 简化)
  12 个动画配置文件                     →  4 个文件 (InstantDriver + TypingDriver + 2 Transition)
  MarkdownRenderEngine (class)         →  MarkdownRenderPipeline (struct)
  onContentHeightChanged 闭包           →  MarkdownContainerViewDelegate 协议
  ViewFragment 无条件 conform ASP       →  条件性 conform
  不存在 ViewStrategy                   →  新增 ViewStrategy 桥接层
  不存在 FragmentContaining             →  新增容器核心协议
  不存在 ViewTransition                 →  新增 View 过渡动画协议
  不存在 ProgressivelyRevealable        →  新增渐进展示协议
  RichLinkRewriter 内置                 →  移除（属业务逻辑）
```

---

## 二、整体策略

**完全重写**，不做渐进迁移。分 6 个 Phase，每个 Phase 结束后可编译。

```
Phase 1: Core 协议与类型           ← 地基
Phase 2: Markdown 数据管线         ← 从输入到 [RenderFragment]
Phase 3: Markdown Views           ← View 实现 + HeightEstimatable
Phase 4: Core 动画与 Diff          ← AnimationDriver + FragmentDiffing
Phase 5: Public 层 + 集成          ← MarkdownContainerView + 组装
Phase 6: 清理 + 测试              ← 删旧文件 + 更新测试
```

---

## 三、Phase 1：Core 协议与类型

> 目标：建立与 Markdown 无关的框架基础设施。此层零 Markdown 引用。

### 新建文件

| 文件 | 内容 |
|---|---|
| `Core/Protocols/RenderFragment.swift` | `protocol RenderFragment { var fragmentId: String; var nodeType: FragmentNodeType; var spacingAfter: CGFloat }` |
| `Core/Protocols/FragmentViewFactory.swift` | `protocol FragmentViewFactory: RenderFragment { var reuseIdentifier: ReuseIdentifier; func makeView() -> UIView; func configure(_ view: UIView) }` 无 theme 参数 |
| `Core/Protocols/LeafFragment.swift` | `protocol LeafFragment: FragmentViewFactory {}` |
| `Core/Protocols/ContainerFragment.swift` | `protocol ContainerFragment: FragmentViewFactory { var childFragments: [RenderFragment] }` |
| `Core/Protocols/FragmentContaining.swift` | `protocol FragmentContaining: AnyObject { func update(_ fragments:); var differ: FragmentDiffing; var animationDriver: AnimationDriver; func dequeueView(...); func recycleView(...) }` |
| `Core/Protocols/FragmentDiffing.swift` | `protocol FragmentDiffing { func diff(old:new:) -> [FragmentChange] }` |
| `Core/Protocols/AnimationDriver.swift` | `protocol AnimationDriver { func apply(changes:fragments:to:); func finishAll() }` |
| `Core/Protocols/HeightEstimatable.swift` | `protocol HeightEstimatable { func estimatedHeight(atDisplayedLength:maxWidth:) -> CGFloat }` 无 theme |
| `Core/Protocols/StreamableContent.swift` | `protocol StreamableContent { func reveal(upTo length: Int) }` |
| `Core/Protocols/ProgressivelyRevealable.swift` | `protocol ProgressivelyRevealable: RenderFragment { var totalContentLength: Int }` |
| `Core/Protocols/TransitionPreferring.swift` | `protocol TransitionPreferring: RenderFragment { var enterTransition: ViewTransition?; var exitTransition: ViewTransition? }` |
| `Core/Protocols/ViewTransition.swift` | `protocol ViewTransition { func animateIn(view:completion:); func animateOut(view:completion:) }` |
| `Core/Protocols/AttributedStringProviding.swift` | `protocol AttributedStringProviding { var attributedString: NSAttributedString? }` opt-in |
| `Core/Protocols/MergeableFragment.swift` | `protocol MergeableFragment: RenderFragment { func canMerge(with:) -> Bool; func merged(with:spacingResolver:) -> RenderFragment }` |
| `Core/Protocols/ContextKey.swift` | `protocol ContextKey { associatedtype Value; static var defaultValue: Value }` |
| `Core/Types/FragmentNodeType.swift` | `struct FragmentNodeType: Hashable, RawRepresentable { let rawValue: String }` |
| `Core/Types/ReuseIdentifier.swift` | `struct ReuseIdentifier: Hashable, RawRepresentable { let rawValue: String }` + 内置静态值 |
| `Core/Types/FragmentContext.swift` | 通用 KV 容器：`struct FragmentContext { private var storage: [ObjectIdentifier: Any]; subscript<K: ContextKey>(...) }` |
| `Core/Types/FragmentChange.swift` | `enum FragmentChange { case insert(...); case remove(...); case update(old:new:childChanges:); case move(...) }` |
| `Core/Types/ViewFragment.swift` | `struct ViewFragment: LeafFragment { ... configure(_ view) 内部调用 configureBlock(view) ... }` 见下方详细设计 |
| `Core/Animation/FadeTransition.swift` | `struct FadeTransition: ViewTransition` |
| `Core/Animation/NoTransition.swift` | `struct NoTransition: ViewTransition` |
| `Core/ViewPool.swift` | View 复用池，按 ReuseIdentifier 管理 |

### ViewFragment 详细设计

```swift
struct ViewFragment: LeafFragment {
    let fragmentId: String
    let nodeType: FragmentNodeType
    let reuseIdentifier: ReuseIdentifier
    var spacingAfter: CGFloat = 0
    let context: FragmentContext

    let content: Any
    private let _makeView: () -> UIView
    private let _configure: (UIView) -> Void

    func makeView() -> UIView { _makeView() }
    func configure(_ view: UIView) { _configure(view) }
}

// 条件性 conform
extension ViewFragment: AttributedStringProviding {
    var attributedString: NSAttributedString? {
        content as? NSAttributedString
    }
}

extension ViewFragment: ProgressivelyRevealable {
    var totalContentLength: Int {
        // 由创建者通过闭包或存储属性决定
        // 如果 content 是 NSAttributedString → .length
        // 否则 → 1（instant）
    }
}

extension ViewFragment: TransitionPreferring {
    var enterTransition: ViewTransition? { _enterTransition }
    var exitTransition: ViewTransition? { _exitTransition }
}
```

> **注意**：ViewFragment 的 `_configure` 闭包在 Render 阶段由 ViewStrategy 创建，捕获了 content + context + theme 的解析结果。此后 Core 层调用 `configure(view)` 时无需传 theme。

### 删除文件

| 文件 | 原因 |
|---|---|
| `Fragments/SpacingFragment.swift` | spacingAfter 替代 |
| `Fragments/RenderFragment.swift` | 重写到 Core/Protocols/ |
| `Fragments/ViewFragment.swift` | 重写到 Core/Types/ |
| `Fragments/BlockQuoteContainerFragment.swift` | 重写为通用 ContainerFragment |
| `Protocols/FragmentViewFactory.swift` | 拆分到 Core/Protocols/ 多个文件 |
| `Protocols/FragmentView.swift` | 废弃，能力并入 FragmentViewFactory |
| `Protocols/FragmentConfigurable.swift` | 废弃，能力并入 FragmentViewFactory.configure |
| `Protocols/MarkdownNodeType.swift` | 替换为 FragmentNodeType |
| `Core/ReuseIdentifier.swift` | 重写为 struct |
| `Core/ContextKey.swift` | 移到 Core/Protocols/ |
| `Core/FragmentContext.swift` | 重写为通用 KV |
| `Core/FragmentIdentifiers.swift` | 常量合并或删除 |
| `Core/PathConstants.swift` | 常量合并或删除 |
| `Core/TextViewConstants.swift` | 常量移入对应 View |
| `Core/CodeBlockConstants.swift` | 常量移入 CodeBlockView |
| `Core/TableLayoutConstants.swift` | 常量移入 MarkdownTableView |

### 检查点

Phase 1 完成后：Core/ 下所有协议和类型可编译，不 import 任何 Markdown/ 或外部模块（除 UIKit/Foundation）。

---

## 四、Phase 2：Markdown 数据管线

> 目标：实现 String → [RenderFragment] 的完整管线。

### 新建文件

| 文件 | 内容 |
|---|---|
| `Markdown/Pipeline/MarkdownRenderPipeline.swift` | `struct MarkdownRenderPipeline` 纯函数：parse → rewrite → render → optimize |
| `Markdown/Pipeline/FragmentOptimizer.swift` | Merge + Filter + SetSpacing，从 MarkdownRenderEngine 内提取 |
| `Markdown/Parser/MarkdownParser.swift` | `protocol MarkdownParser { func parse(_ text: String) -> MarkdownNode }` |
| `Markdown/Parser/MarkdownNode.swift` | `protocol MarkdownNode { var nodeType: MarkdownNodeType; var children: [MarkdownNode] }` + 子协议 |
| `Markdown/Parser/XYMarkdown/XYMarkdownParser.swift` | 实现 MarkdownParser，包装 XYMarkdown/cmark |
| `Markdown/Parser/XYMarkdown/XYNodeAdapters.swift` | XYMarkdown Markup → MarkdownNode 适配器 |
| `Markdown/Renderer/NodeRenderer.swift` | `protocol NodeRenderer`, `protocol LeafNodeRenderer` |
| `Markdown/Renderer/RendererRegistry.swift` | 重写，用 FragmentNodeType 替代 MarkdownNodeType |
| `Markdown/Renderer/InlineRenderer.swift` | 从现有 InlineRenderer 移植 |
| `Markdown/Renderer/Defaults/` | 每个节点类型一个文件（从 DefaultRenderers.swift 拆分） |
| `Markdown/ViewStrategy/TextViewStrategy.swift` | **新增** `protocol TextViewStrategy { func makeView() -> UIView; func configure(view:content:context:theme:) }` + DefaultTextViewStrategy |
| `Markdown/ViewStrategy/CodeBlockViewStrategy.swift` | **新增** 同上模式 |
| `Markdown/ViewStrategy/TableViewStrategy.swift` | **新增** |
| `Markdown/ViewStrategy/ImageViewStrategy.swift` | **新增** |
| `Markdown/ViewStrategy/ThematicBreakViewStrategy.swift` | **新增** |
| `Markdown/Spacing/DefaultBlockSpacingResolver.swift` | 从现有 BlockSpacingResolving.swift 移植 |
| `Markdown/Rewriter/RewriterPipeline.swift` | 保留框架，移除具体 Rewriter |
| `Markdown/Context/RenderContext.swift` | 重写：Environment 模式，ContextKey 机制 |
| `Markdown/Context/MarkdownContextKeys.swift` | **新增** `BlockQuoteDepthKey`, `IndentKey`, `ListItemIndexKey` 等具体 key |
| `Markdown/Types/MarkdownNodeTypes.swift` | **新增** `extension FragmentNodeType { static let paragraph = ...; ... }` |
| `Markdown/Theme/MarkdownTheme.swift` | 基本保留，清理不需要的 animation 配置 |
| `Markdown/State/FragmentStateStore.swift` | 保留 |
| `Markdown/State/FragmentEvent.swift` | 保留 |

### ViewStrategy 工作方式

以 TextViewStrategy 为例：

```swift
// Markdown/ViewStrategy/TextViewStrategy.swift

protocol TextViewStrategy {
    func makeView() -> UIView
    func configure(
        view: UIView,
        attributedString: NSAttributedString,
        context: FragmentContext,
        theme: MarkdownTheme
    )
    var enterTransition: ViewTransition? { get }
    var exitTransition: ViewTransition? { get }
}

struct DefaultTextViewStrategy: TextViewStrategy {
    func makeView() -> UIView { MarkdownTextView() }

    func configure(view: UIView, attributedString: NSAttributedString,
                   context: FragmentContext, theme: MarkdownTheme) {
        guard let textView = view as? MarkdownTextView else { return }
        // 解析 context + theme → 具体值
        let indent = context[IndentKey.self]
        let font = theme.bodyFont
        // 配置 View（传具体值，不传 theme）
        textView.configure(
            attributedString: attributedString,
            indent: indent,
            lineSpacing: theme.lineSpacing,
            font: font
        )
    }

    var enterTransition: ViewTransition? { FadeTransition(duration: 0.15) }
    var exitTransition: ViewTransition? { nil }
}
```

### Renderer 如何使用 ViewStrategy

```swift
// Markdown/Renderer/Defaults/ParagraphRenderer.swift

struct ParagraphRenderer: LeafNodeRenderer {
    func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard let paragraph = node as? ParagraphNode else { return [] }

        let attrString = InlineRenderer.render(paragraph.inlineChildren, context: context)
        let strategy = context[TextViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()

        return [ViewFragment(
            fragmentId: context.pathPrefix + "/paragraph",
            nodeType: .paragraph,
            reuseIdentifier: .textView,
            context: fragmentContext,
            content: attrString,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, attributedString: attrString,
                                   context: fragmentContext, theme: context.theme)
            },
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            totalContentLength: attrString.length
        )]
    }
}
```

> 关键点：`configure` 闭包在 Render 阶段创建，捕获了 `strategy`、`attrString`、`fragmentContext`、`context.theme`。Core 层调用 `fragment.configure(view)` 时执行此闭包，theme 已被捕获，Core 不需要知道 theme 的存在。

### DefaultRenderers.swift 拆分计划

```
现有 DefaultRenderers.swift (568 行, 所有 renderer 在一个文件)
  ↓ 拆分为
Markdown/Renderer/Defaults/
  ├── DocumentRenderer.swift          DefaultDocumentRenderer
  ├── ParagraphRenderer.swift         DefaultParagraphRenderer → 注入 TextViewStrategy
  ├── HeadingRenderer.swift           DefaultHeadingRenderer → 注入 TextViewStrategy
  ├── CodeBlockRenderer.swift         DefaultCodeBlockRenderer → 注入 CodeBlockViewStrategy
  ├── BlockQuoteRenderer.swift        DefaultBlockQuoteRenderer → 产出 ContainerFragment
  ├── ListRenderer.swift              DefaultOrderedListRenderer + DefaultUnorderedListRenderer
  ├── ListItemRenderer.swift          DefaultListItemRenderer → 注入 TextViewStrategy
  ├── TableRenderer.swift             DefaultTableRenderer → 注入 TableViewStrategy
  ├── ThematicBreakRenderer.swift     DefaultThematicBreakRenderer
  └── ImageRenderer.swift             DefaultImageRenderer → 注入 ImageViewStrategy
```

每个 Renderer 重写要点：
- 内容提取逻辑基本保留
- 不再直接创建 View 或调用 View 方法
- 通过 ViewStrategy 创建 ViewFragment
- configure 闭包捕获 theme，不暴露给 Core
- 产出 FragmentNodeType（struct）而非 MarkdownNodeType（enum）
- ContainerFragment 通过 ChildRenderer 递归

### 删除文件

| 文件 | 原因 |
|---|---|
| `Engine/MarkdownRenderEngine.swift` | 替换为 MarkdownRenderPipeline |
| `Engine/NodeRenderer.swift` | 移到 Markdown/Renderer/ |
| `Engine/RendererRegistry.swift` | 移到 Markdown/Renderer/ |
| `Engine/RendererCategory.swift` | 废弃 |
| `Engine/Defaults/DefaultRenderers.swift` | 拆分到 Markdown/Renderer/Defaults/ |
| `Engine/Defaults/InlineRenderer.swift` | 移到 Markdown/Renderer/ |
| `Protocols/BlockSpacingResolving.swift` | 协议移到 Markdown/Spacing/ |
| `Core/ContextKeys.swift` | 拆分到 Markdown/Context/MarkdownContextKeys.swift |
| `Core/RenderContext.swift` | 移到 Markdown/Context/ |
| `Core/MarkdownRenderResult.swift` | 废弃（Pipeline 直接返回 [RenderFragment]）|
| `Rewriter/RichLinkRewriter.swift` | 移除（属业务逻辑，移到 Example）|

### 检查点

Phase 2 完成后：`MarkdownRenderPipeline.render(text, maxWidth, theme, stateStore)` 可编译，返回 `[RenderFragment]`。每个 Fragment 的 `configure(_ view)` 已捕获全部信息。

---

## 五、Phase 3：Markdown Views

> 目标：所有 View 实现 HeightEstimatable，configure 签名改为接收具体值（不接收 theme）。

### 改写文件

| 文件 | 改动 |
|---|---|
| `Markdown/Views/MarkdownTextView.swift` | 1. `configure(attributedString:indent:lineSpacing:font:)` 不接收 theme<br>2. 实现 `HeightEstimatable.estimatedHeight(atDisplayedLength:maxWidth:)`<br>3. 实现 `StreamableContent.reveal(upTo:)`<br>4. 内部存储 font/lineSpacing 用于高度计算 |
| `Markdown/Views/BlockQuoteTextView.swift` | 同上 + `configure(attributedString:indent:lineColor:lineWidth:)` |
| `Markdown/Views/BlockQuoteContainerView.swift` | 1. 实现 `FragmentContaining`（递归容器）<br>2. 实现 `HeightEstimatable`（递归求和）<br>3. `configure(childFragments:leftInset:lineColor:lineWidth:)` |
| `Markdown/Views/CodeBlockView.swift` | 1. `configure(code:language:backgroundColor:font:cornerRadius:copyState:)` 不接收 theme<br>2. 实现 `HeightEstimatable`<br>3. 实现 `StreamableContent.reveal(upTo:)` |
| `Markdown/Views/MarkdownTableView.swift` | 1. `configure(tableData:font:headerFont:borderColor:)` 不接收 theme<br>2. 实现 `HeightEstimatable` |
| `Markdown/Views/MarkdownImageView.swift` | 1. `configure(source:title:maxWidth:)` 不接收 theme<br>2. 实现 `HeightEstimatable` |
| `Markdown/Views/ThematicBreakView.swift` | 1. `configure(color:height:)` 不接收 theme<br>2. 实现 `HeightEstimatable`（固定高度）|

### View configure 改造原则

**Before**（现有）：

```swift
class MarkdownTextView {
    func configure(with attributedString: NSAttributedString, theme: MarkdownTheme) {
        self.font = theme.bodyFont           // View 内部从 theme 取值
        self.lineSpacing = theme.lineSpacing
        // ...
    }
}
```

**After**（理想）：

```swift
class MarkdownTextView: HeightEstimatable, StreamableContent {
    private var attributedString: NSAttributedString?
    private var indent: CGFloat = 0
    private var lineSpacing: CGFloat = 0

    func configure(attributedString: NSAttributedString, indent: CGFloat, lineSpacing: CGFloat) {
        self.attributedString = attributedString
        self.indent = indent
        self.lineSpacing = lineSpacing
        // 布局...
    }

    func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        // 用内部已存储的 attributedString + indent + lineSpacing 计算
    }

    func reveal(upTo length: Int) {
        // 截取 attributedString 的前 length 个字符显示
    }
}
```

> View 不知道 MarkdownTheme 的存在。所有具体值由 ViewStrategy 在 Render 阶段解析并通过 configure 闭包传入。

### 检查点

Phase 3 完成后：所有 View 实现 HeightEstimatable + 可选 StreamableContent，configure 签名无 theme。

---

## 六、Phase 4：Core 动画与 Diff

> 目标：实现 DefaultFragmentDiffer + InstantDriver + TypingDriver。

### 新建文件

| 文件 | 内容 |
|---|---|
| `Core/Diff/DefaultFragmentDiffer.swift` | 实现 `FragmentDiffing`：<br>1. 基于 fragmentId 匹配<br>2. ContainerFragment 递归 diff childFragments<br>3. update 携带 childChanges |
| `Core/Animation/InstantDriver.swift` | 实现 `AnimationDriver`：<br>收到 changes → 立即创建/更新/删除 View<br>尊重 TransitionPreferring |
| `Core/Animation/TypingDriver.swift` | 实现 `AnimationDriver`：<br>维护 target/displayed/pending<br>DisplayLink tick 驱动<br>Fragment 级变更处理（5 条规则）<br>内容截短处理 |

### DefaultFragmentDiffer 设计

```swift
struct DefaultFragmentDiffer: FragmentDiffing {
    func diff(old: [RenderFragment], new: [RenderFragment]) -> [FragmentChange] {
        var changes: [FragmentChange] = []
        let oldMap = Dictionary(old.enumerated().map { ($1.fragmentId, $0) }, uniquingKeysWith: { _, new in new })

        // 1. 找 remove: old 中有但 new 中无
        // 2. 找 insert: new 中有但 old 中无
        // 3. 找 update: 两边都有，内容变化
        //    - 若是 ContainerFragment，递归 diff childFragments → childChanges
        // 4. 找 move: 位置变化

        return changes
    }
}
```

### TypingDriver 状态机

```swift
class TypingDriver: AnimationDriver {
    private var targetFragments: [RenderFragment] = []
    private var displayedFragments: [RenderFragment] = []
    private var pendingQueue: [RenderFragment] = []

    private var currentFragmentIndex: Int = 0
    private var displayedLength: Int = 0

    private var displayLink: CADisplayLink?
    private weak var container: FragmentContaining?

    func apply(changes: [FragmentChange], fragments: [RenderFragment], to container: FragmentContaining) {
        self.container = container
        targetFragments = fragments

        // 按 3.4 节 5 条规则处理每种 change
        // ...

        if displayLink == nil { startDisplayLink() }
    }

    @objc private func tick() {
        // 当前 fragment 完成 → 取 pending 下一个
        // displayedLength += step
        // view.reveal(upTo:)
        // height = view.estimatedHeight(atDisplayedLength:maxWidth:)
        // relayout (最后一个不加 spacingAfter)
    }

    func finishAll() {
        // 立即完成所有 pending，停止 displayLink
    }
}
```

### 删除文件

| 文件 | 原因 |
|---|---|
| `Animation/StreamAnimator.swift` | 替换为 TypingDriver |
| `Animation/InstantAnimationDriver.swift` | 替换为 InstantDriver |
| `Animation/FragmentAnimationDriver.swift` | 替换为 AnimationDriver 协议 |
| `Animation/AnimationConfig.swift` | 废弃（配置简化）|
| `Animation/AnimationConfiguration.swift` | 废弃 |
| `Animation/AnimationConstants.swift` | 废弃 |
| `Animation/AlphaFadeConstants.swift` | 废弃 |
| `Animation/ContentChangeAnalyzer.swift` | 废弃 |
| `Animation/EnterAnimationExecutor.swift` | 替换为 ViewTransition |
| `Animation/RevealSpeedStrategy.swift` | 简化进 TypingDriver |
| `Animation/TextRevealStrategy.swift` | 替换为 StreamableContent |
| `Animation/TextDisplayTarget.swift` | 废弃 |
| `Animation/StreamableContent.swift` | 移到 Core/Protocols/ |
| `Streaming/FragmentDiffer.swift` | 替换为 DefaultFragmentDiffer |
| `Streaming/StreamingSpeedStrategy.swift` | 废弃 |

### 检查点

Phase 4 完成后：`DefaultFragmentDiffer.diff()` 可递归 diff；`InstantDriver.apply()` 可立即应用变更；`TypingDriver` 可逐字插值。

---

## 七、Phase 5：Public 层 + 集成

> 目标：重写 MarkdownContainerView，实现 FragmentContaining + delegate + 便捷 API。

### 改写文件

| 文件 | 改动 |
|---|---|
| `Public/MarkdownContainerView.swift` | **大幅重写**：<br>1. 实现 `FragmentContaining` 协议<br>2. 持有 `MarkdownRenderPipeline`<br>3. delegate 替代闭包回调<br>4. `setText` / `appendText` 内部调用 pipeline.render + update<br>5. ViewPool 与嵌套容器共享 |
| `Public/MarkdownKit.swift` | 更新工厂方法签名 |

### 新建文件

| 文件 | 内容 |
|---|---|
| `Markdown/Delegate/MarkdownContainerViewDelegate.swift` | delegate 协议：didChangeContentHeight / didCompleteAnimation / didReceiveEvent |
| `Public/MarkdownConfiguration.swift` | 重写：简化配置（pipeline + theme + driver + differ）|

### MarkdownContainerView 重写

```swift
class MarkdownContainerView: UIView, FragmentContaining {

    // MARK: - FragmentContaining

    var differ: FragmentDiffing = DefaultFragmentDiffer()
    var animationDriver: AnimationDriver = InstantDriver()
    private(set) var currentFragments: [RenderFragment] = []
    private let viewPool = ViewPool()

    func update(_ fragments: [RenderFragment]) {
        let changes = differ.diff(old: currentFragments, new: fragments)
        currentFragments = fragments
        animationDriver.apply(changes: changes, fragments: fragments, to: self)
    }

    func dequeueView(reuseIdentifier: ReuseIdentifier, factory: () -> UIView) -> UIView {
        viewPool.dequeue(reuseIdentifier: reuseIdentifier, factory: factory)
    }

    func recycleView(_ view: UIView, reuseIdentifier: ReuseIdentifier) {
        viewPool.recycle(view, reuseIdentifier: reuseIdentifier)
    }

    // MARK: - Markdown 数据层

    private var pipeline: MarkdownRenderPipeline
    private var theme: MarkdownTheme
    private var stateStore = FragmentStateStore()
    private var preprocessor = MarkdownPreprocessor()

    // MARK: - Delegate (协议，非闭包)

    weak var delegate: MarkdownContainerViewDelegate?

    // MARK: - 便捷 API

    func setText(_ text: String) {
        let fragments = pipeline.render(text, maxWidth: bounds.width, theme: theme, stateStore: stateStore)
        update(fragments)
    }

    func appendText(_ chunk: String) {
        preprocessor.append(chunk)
        let preclosed = preprocessor.preclosedText
        let fragments = pipeline.render(preclosed, maxWidth: bounds.width, theme: theme, stateStore: stateStore)
        update(fragments)
    }

    func skipAnimation() {
        animationDriver.finishAll()
    }

    func clear() {
        update([])
        preprocessor.reset()
    }
}
```

### 删除文件

| 文件 | 原因 |
|---|---|
| `Public/MarkdownConfiguration.swift` | 重写 |
| `Cache/DocumentCache.swift` | 废弃（全量 render + diff，无需文档级缓存）|

### 检查点

Phase 5 完成后：完整管线可工作——`containerView.setText("# Hello")` 从解析到渲染到显示全部走通。

---

## 八、Phase 6：清理 + 测试

### 删除残余旧文件

```
待删除（Phase 1-5 中未提及但需清理的）:
  Core/MarkdownRenderResult.swift          Pipeline 直接返回数组
  Core/PathConstants.swift                 合并到 Renderer 内部
  Core/TextViewConstants.swift             移入 View 内部
  Core/CodeBlockConstants.swift            移入 View 内部
  Core/TableLayoutConstants.swift          移入 View 内部
  Extensions/Markup+Sibling.swift          XYMarkdown 适配层内部化
  State/FragmentState.swift                评估是否仍需要
  State/States/CodeBlockInteractionState.swift  移入 Markdown/State/
  Streaming/StreamingSpeedStrategy.swift   废弃
  XHSMarkdownKit.swift (root)             评估是否仍需要
```

### 更新测试

| 测试文件 | 改动 |
|---|---|
| `FragmentTests.swift` | 使用新 ViewFragment API，FragmentNodeType struct，条件性 AttributedStringProviding |
| `CustomNodeRegistrationTests.swift` | 使用新 RendererRegistry + FragmentNodeType + ViewStrategy |
| `RendererOverrideTests.swift` | 使用新 RendererRegistry |
| `SpacingResolverTests.swift` | 使用新 BlockSpacingResolving + spacingAfter（无 SpacingFragment）|
| `BlockQuoteRenderTests.swift` | ContainerFragment + childFragments |
| `CodeBlockRenderTests.swift` | 新 configure 签名 |
| `HeadingRenderTests.swift` | 新 ViewStrategy |
| `ListRenderTests.swift` | 新 ViewStrategy + FragmentNodeType |
| `TableRenderTests.swift` | 新 ViewStrategy |
| `RichLinkRewriterTests.swift` | 移到 Example 或删除（RichLinkRewriter 不再内置）|
| `ThemeCustomizationTests.swift` | 更新 theme 配置项 |
| `RenderPerformanceTests.swift` | 使用新 Pipeline API |
| `DocumentCacheTests.swift` | 删除（DocumentCache 废弃）|

### 新增测试

| 测试文件 | 内容 |
|---|---|
| `CoreProtocolTests.swift` | 验证 Core 协议不依赖 Markdown 类型 |
| `ViewStrategyTests.swift` | 验证 Strategy 桥接：context + theme → 具体值 |
| `HeightEstimatableTests.swift` | 验证 View 的 estimatedHeight 无 theme 参数 |
| `FragmentDifferTests.swift` | 验证递归 diff + childChanges |
| `InstantDriverTests.swift` | 验证立即应用 |
| `TypingDriverTests.swift` | 验证逐字插值 + Fragment 级变更处理 |
| `TransitionTests.swift` | 验证 FadeTransition / NoTransition |

### 执行

```bash
cd Example && pod install
# 编译验证
xcodebuild -workspace Example.xcworkspace -scheme ExampleApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 检查点

Phase 6 完成后：所有旧文件清除，所有测试通过，pod install 成功，编译无 error。

---

## 九、文件变更总表

### 新建（约 40 文件）

```
Core/Protocols/
  RenderFragment.swift, FragmentViewFactory.swift, LeafFragment.swift,
  ContainerFragment.swift, FragmentContaining.swift, FragmentDiffing.swift,
  AnimationDriver.swift, HeightEstimatable.swift, StreamableContent.swift,
  ProgressivelyRevealable.swift, TransitionPreferring.swift, ViewTransition.swift,
  AttributedStringProviding.swift, MergeableFragment.swift, ContextKey.swift

Core/Types/
  ViewFragment.swift, FragmentNodeType.swift, ReuseIdentifier.swift,
  FragmentContext.swift, FragmentChange.swift

Core/Animation/
  InstantDriver.swift, TypingDriver.swift, FadeTransition.swift, NoTransition.swift

Core/Diff/
  DefaultFragmentDiffer.swift

Core/
  ViewPool.swift

Markdown/Pipeline/
  MarkdownRenderPipeline.swift, FragmentOptimizer.swift

Markdown/Parser/
  MarkdownParser.swift, MarkdownNode.swift,
  XYMarkdown/XYMarkdownParser.swift, XYMarkdown/XYNodeAdapters.swift

Markdown/Renderer/
  NodeRenderer.swift, RendererRegistry.swift, InlineRenderer.swift

Markdown/Renderer/Defaults/
  DocumentRenderer.swift, ParagraphRenderer.swift, HeadingRenderer.swift,
  CodeBlockRenderer.swift, BlockQuoteRenderer.swift, ListRenderer.swift,
  ListItemRenderer.swift, TableRenderer.swift, ThematicBreakRenderer.swift,
  ImageRenderer.swift

Markdown/ViewStrategy/
  TextViewStrategy.swift, CodeBlockViewStrategy.swift, TableViewStrategy.swift,
  ImageViewStrategy.swift, ThematicBreakViewStrategy.swift

Markdown/Spacing/
  DefaultBlockSpacingResolver.swift

Markdown/Rewriter/
  RewriterPipeline.swift

Markdown/Context/
  RenderContext.swift, MarkdownContextKeys.swift

Markdown/Types/
  MarkdownNodeTypes.swift

Markdown/Delegate/
  MarkdownContainerViewDelegate.swift
```

### 保留并改写（约 10 文件）

```
Markdown/Views/
  MarkdownTextView.swift        + HeightEstimatable + StreamableContent + 新 configure
  BlockQuoteTextView.swift      + HeightEstimatable + 新 configure
  BlockQuoteContainerView.swift + FragmentContaining + HeightEstimatable + 新 configure
  CodeBlockView.swift           + HeightEstimatable + StreamableContent + 新 configure
  MarkdownTableView.swift       + HeightEstimatable + 新 configure
  MarkdownImageView.swift       + HeightEstimatable + 新 configure
  (ThematicBreakView.swift 如不存在则新建)

Markdown/Theme/MarkdownTheme.swift    清理 animation 配置
Markdown/State/FragmentStateStore.swift   保留
Markdown/State/FragmentEvent.swift        保留
Markdown/Streaming/MarkdownPreprocessor.swift  保留
Markdown/Streaming/StreamingTextBuffer.swift   保留

Public/MarkdownContainerView.swift    大幅重写
Public/MarkdownKit.swift              更新 API
Extensions/UIFont+Traits.swift        保留
Extensions/NSAttributedString+Markdown.swift  保留
```

### 删除（约 30 文件）

```
Animation/
  AnimationConfig.swift, AnimationConfiguration.swift, AnimationConstants.swift,
  AlphaFadeConstants.swift, ContentChangeAnalyzer.swift, EnterAnimationExecutor.swift,
  FragmentAnimationDriver.swift, InstantAnimationDriver.swift, RevealSpeedStrategy.swift,
  StreamableContent.swift, StreamAnimator.swift, TextDisplayTarget.swift,
  TextRevealStrategy.swift

Core/
  CodeBlockConstants.swift, ContextKey.swift, ContextKeys.swift, FragmentContext.swift,
  FragmentIdentifiers.swift, MarkdownRenderResult.swift, PathConstants.swift,
  RenderContext.swift, ReuseIdentifier.swift, TableLayoutConstants.swift,
  TextViewConstants.swift

Engine/
  MarkdownRenderEngine.swift, NodeRenderer.swift, RendererRegistry.swift,
  RendererCategory.swift, Defaults/DefaultRenderers.swift, Defaults/InlineRenderer.swift

Fragments/
  BlockQuoteContainerFragment.swift, RenderFragment.swift, SpacingFragment.swift,
  ViewFragment.swift

Protocols/
  BlockSpacingResolving.swift, FragmentConfigurable.swift, FragmentView.swift,
  FragmentViewFactory.swift, MarkdownNodeType.swift

Rewriter/
  RichLinkRewriter.swift

Streaming/
  FragmentDiffer.swift, StreamingSpeedStrategy.swift

State/
  FragmentState.swift, States/CodeBlockInteractionState.swift (移到 Markdown/State/)

Cache/
  DocumentCache.swift

Public/
  MarkdownConfiguration.swift

XHSMarkdownKit.swift (root, 评估)
```

---

## 十、执行顺序与依赖

```
Phase 1 (Core)
  │  无依赖
  ▼
Phase 2 (数据管线)
  │  依赖 Phase 1 的 Core 协议
  ▼
Phase 3 (Views)
  │  依赖 Phase 1 (HeightEstimatable) + Phase 2 (ViewStrategy 定义了 View 接口)
  ▼
Phase 4 (动画 & Diff)
  │  依赖 Phase 1 (AnimationDriver, FragmentDiffing) + Phase 3 (View 实现)
  ▼
Phase 5 (Public 集成)
  │  依赖 Phase 1-4 全部
  ▼
Phase 6 (清理 & 测试)
     依赖 Phase 1-5 全部
```

**可并行**：Phase 2 和 Phase 3 可并行开发（ViewStrategy 定义接口 → View 实现接口）。Phase 4 可在 Phase 2 完成后开始（不强依赖 Phase 3 的 View 实现，可用 mock View 测试）。

---

## 十一、风险与应对

| 风险 | 应对 |
|---|---|
| XYMarkdown AST 适配层工作量大 | 最小适配：只做 Markup → MarkdownNode 的 1:1 映射，不改解析逻辑 |
| ViewStrategy 导致 Renderer 代码量增加 | 每个 Renderer 的核心逻辑（内容提取）不变，只是多了 Strategy 调用。增量可控 |
| TypingDriver 状态机复杂 | 先实现 InstantDriver 跑通全流程，再实现 TypingDriver |
| configure 闭包捕获 theme 的内存 | theme 是 struct（值类型），闭包捕获的是副本，Fragment 生命周期短暂（每次 render 重建），无泄漏风险 |
| 递归 ContainerFragment + 递归 diff | 先用单层 BlockQuote 验证，再扩展到多层嵌套 |
