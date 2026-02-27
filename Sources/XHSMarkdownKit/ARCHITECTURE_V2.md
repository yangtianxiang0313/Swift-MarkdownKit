# XHSMarkdownKit 架构重构方案 V2

> **版本**: 2.1
> **基于**: Markdown Pod重写设计方案.md v1.9
> **目标**: 统一 Fragment 流 + 无状态渲染 + 完整流式动画支持

## 第一性原理分析

### 最终目标

> 一个复杂的超 Markdown 格式数据（标准 Markdown + 自定义 View），能够**按可自定义速率**播放的 UI 动画：
> - 文字部分：**逐字动画**
> - View 部分：**进入动画 + 内部内容逐字动画**
> - 增量刷新：**只更新变化的部分**

### Markdown 渲染的本质

```
输入: Markdown 文本
  ↓ (解析)
中间: AST 树 (Document → Block → Inline)
  ↓ (遍历转换)
输出: 可展示的 Fragment 流
```

**核心洞察**：
1. Markdown 是**树形结构**，渲染就是**树的遍历 + 转换**
2. 每个节点独立产生输出，父节点组合子节点的输出
3. 输出是**有序的 Fragment 流**，顺序由遍历顺序决定

### 设计目标

1. **正确性**：任意嵌套场景下顺序正确
2. **可扩展**：轻松添加新节点类型
3. **可自定义**：替换任意节点的渲染逻辑
4. **高性能**：避免不必要的计算和内存分配
5. **易测试**：纯函数，无副作用
6. **流式友好**：支持增量渲染和平滑动画

### 设计原则

1. **协议优于基类（Protocol over Inheritance）**
   - 使用协议 + 协议扩展提供默认实现
   - 避免类继承带来的耦合和脆弱基类问题
   - 新增功能通过组合协议实现，而非继承链
   
   ```swift
   // ✅ 正确：协议 + 协议扩展
   protocol AnimatableContent { ... }
   protocol TextContentStorage { ... }
   extension AnimatableContent where Self: TextContentStorage { /* 默认实现 */ }
   
   // ❌ 避免：基类继承
   class AnimatableTextView: UIView { ... }
   class CodeBlockView: AnimatableTextView { ... }
   ```

2. **禁止硬编码（Never Hardcode）**
   - 所有配置项通过 Theme、Configuration 或 ContextKey 传递
   - 不在代码中写死颜色、字体、间距等数值
   - 类型判断使用协议而非 `is SomeClass`
   
   ```swift
   // ✅ 正确：从配置获取
   let indent = context.theme.list.nestingIndent
   let color = context.theme.code.block.backgroundColor
   
   // ❌ 避免：硬编码
   let indent: CGFloat = 16
   let color = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
   ```
   
   ```swift
   // ✅ 正确：协议判断
   if let animatable = view as? AnimatableContent { ... }
   
   // ❌ 避免：具体类型判断
   if view is CodeBlockView { ... }
   else if view is TableView { ... }
   ```

3. **可扩展性优先（Extensibility First）**
   - 新增 View 不需要修改框架核心代码
   - 新增 Context 需求通过 ContextKey 扩展
   - 新增渲染器通过 Registry 注册

4. **尽可能配置化（Configuration over Code）**
   - 行为差异通过配置表达，而非代码分支
   - 提供合理的默认值，允许覆盖
   - 配置项应该是声明式的，描述"是什么"而非"怎么做"
   
   ```swift
   // ✅ 正确：通过配置描述行为
   struct CodeBlockView: AnimatableContent {
       var enterAnimationConfig: EnterAnimationConfig? { .default }
       var contentAnimationConfig: ContentAnimationConfig? { .code }
   }
   
   // ❌ 避免：代码中写逻辑分支
   func animateView(_ view: UIView) {
       if view is CodeBlockView {
           // 代码块动画逻辑
       } else if view is TableView {
           // 表格动画逻辑
       }
   }
   ```
   
   ```swift
   // ✅ 正确：配置驱动
   let config = ContentAnimationConfig(
       speedMultiplier: 1.5,
       granularity: .character
   )
   
   // ❌ 避免：散落在各处的魔法数字
   let charsPerFrame = 5  // 为什么是 5？
   ```

5. **禁止单例（No Singleton）**
   - 所有依赖通过构造函数注入或配置传递
   - 单例在多实例场景下必然出问题（多个 Markdown 视图、不同配置）
   - 使用依赖注入而非全局状态
   
   ```swift
   // ✅ 正确：依赖注入
   let engine = MarkdownRenderEngine(
       registry: myCustomRegistry,
       theme: darkTheme,
       configuration: .init(maxWidth: 300)
   )
   let containerView = MarkdownContainerView(
       engine: engine,
       animationConfig: myAnimationConfig
   )
   
   // ❌ 避免：单例
   class RendererRegistry {
       static let shared = RendererRegistry()  // 不要这样！
   }
   MarkdownKit.shared.render(text)  // 不要这样！
   ```
   
   ```swift
   // ✅ 正确：工厂方法提供默认配置
   extension MarkdownRenderEngine {
       static func makeDefault() -> MarkdownRenderEngine {
           MarkdownRenderEngine(
               registry: .makeDefault(),
               theme: .default,
               configuration: .default
           )
       }
   }
   
   // ❌ 避免：隐式依赖全局状态
   func render() {
       let theme = GlobalConfig.shared.theme  // 不要这样！
   }
   ```

---

## 分层架构

### 从目标倒推的依赖链

```
【动画播放】
    │ 需要
    ▼
【知道变化】insert / update / delete 是什么
    │ 需要
    ▼
【前后对比】前一次的 [Fragment] vs 当前的 [Fragment]
    │ 需要
    ▼
【渲染结果】当前文本 → [Fragment]
    │ 需要
    ▼
【AST】当前文本 → Document
    │ 需要
    ▼
【可解析文本】原始文本（流式场景可能不完整，需要预处理）
```

### 四层架构

```
┌─────────────────────────────────────────────────────────────────┐
│ 层 1：输入层                                                     │
│                                                                  │
│ 非流式：text                                                     │
│ 流式：StreamingBuffer（累积 + 节流）                              │
│                                                                  │
│ 输出：完整文本                                                    │
│ 依赖：无                                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 层 2：Markdown 层（MarkdownKit 内部）                            │
│                                                                  │
│ MarkdownKit.render(text, mode: .streaming)                      │
│                                                                  │
│ 内部：                                                           │
│ ├── 预处理（补全未闭合标记）← 需要 Markdown 知识，必须在内部       │
│ ├── 解析（cmark）                                                │
│ └── 渲染（AST → Fragment）                                       │
│                                                                  │
│ 输出：[Fragment]                                                  │
│ 依赖：Markdown 语法、cmark                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 层 3：Diff 层                                                    │
│                                                                  │
│ FragmentDiffer.diff(old, new)                                   │
│                                                                  │
│ 输出：[Change]（insert / update / delete）                       │
│ 依赖：只需要 ID 比较，不需要 Markdown 知识                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 层 4：UI 层                                                      │
│                                                                  │
│ MarkdownContainerView                                           │
│ ├── 布局计算（frame）                                            │
│ ├── View 管理（创建 / 复用 / 删除）                               │
│ └── AnimationController（内嵌）                                  │
│     ├── 统一管理所有动画（文字 + View + View 内部文字）            │
│     ├── 目标进度 + 每帧趋近（不用原子队列）                        │
│     ├── 顺序控制（前一个完成才开始下一个）                         │
│     └── 速度控制（动态调整、快进）                                 │
│                                                                  │
│ 输出：屏幕上的 View + 动画                                        │
│ 依赖：UIKit、[Fragment]、[Change]                                │
└─────────────────────────────────────────────────────────────────┘
```

### 分层原则

| 层 | 依赖 | 理解什么 |
|---|---|---|
| 输入层 | 无 | 只理解字符串 |
| Markdown 层 | Markdown 语法、cmark | 理解 Markdown 结构 |
| Diff 层 | Fragment ID | 只理解"相同/不同" |
| UI 层 | UIKit、动画 | 理解 View 和动画 |

---

## 核心架构

### 1. Fragment 类型系统

```swift
/// 渲染片段协议
public protocol RenderFragment {
    var fragmentId: String { get }
    var nodeType: MarkdownNodeType { get }
}

/// 文本片段
public struct TextFragment: RenderFragment {
    public let fragmentId: String
    public let nodeType: MarkdownNodeType
    public let attributedString: NSAttributedString
}

/// 视图片段
public struct ViewFragment: RenderFragment {
    public let fragmentId: String
    public let nodeType: MarkdownNodeType
    public let reuseIdentifier: String
    public let estimatedSize: CGSize
    public let content: Any  // 内容数据（用于更新）
    public let makeView: () -> UIView
    public let configure: (UIView, Any) -> Void
}
```

### 2. 节点渲染器协议

```swift
/// 节点渲染器协议（核心扩展点）
public protocol NodeRenderer {
    /// 渲染节点，返回 Fragment 数组
    func render(
        node: Markup,
        context: RenderContext,
        children: () -> [RenderFragment]  // 惰性获取子节点渲染结果
    ) -> [RenderFragment]
}
```

### 3. RenderContext 详细设计（Environment 模式）

#### 第一性原理分析

渲染一个节点时，信息有三个来源：

```
┌─────────────────────────────────────────────────────────────────┐
│ 来源 1：节点本身                                                 │
│ ├── 节点类型、内容、属性                                         │
│ └── 节点位置（indexInParent）                                    │
│     → 不需要 Context，节点自己知道                                │
├─────────────────────────────────────────────────────────────────┤
│ 来源 2：向下传递（Context）                                       │
│ ├── 全局配置（theme、maxWidth）                                   │
│ └── 累积计算的结果（indent = 父链缩进累加）                        │
│     → 需要 Context 传递                                          │
├─────────────────────────────────────────────────────────────────┤
│ 来源 3：遍历父链获取                                              │
│ └── 罕见场景，可以保留 parentChain                                │
└─────────────────────────────────────────────────────────────────┘
```

**Context 的职责**：
1. 传递全局配置（不变）
2. 传递累积计算的结果（避免每次重新遍历父链）

#### 设计目标

1. **最小核心**：只包含 99% 渲染都需要的字段
2. **可扩展**：新增 View 不需要修改 Context 结构
3. **类型安全**：编译期检查

#### Environment 模式实现

```swift
// MARK: - Context Key 协议

/// 定义 Context 中的值类型
public protocol ContextKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

// MARK: - RenderContext（类似 SwiftUI 的 Environment）

public struct RenderContext {
    private var storage: [ObjectIdentifier: Any] = [:]
    
    /// 读取值
    public subscript<K: ContextKey>(key: K.Type) -> K.Value {
        storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }
    
    /// 设置值，返回新 Context（不可变）
    public func setting<K: ContextKey>(_ key: K.Type, to value: K.Value) -> RenderContext {
        var copy = self
        copy.storage[ObjectIdentifier(key)] = value
        return copy
    }
    
    /// 初始化
    public init() {}
    
    /// 带初始值的初始化
    public static func initial(theme: MarkdownTheme, maxWidth: CGFloat) -> RenderContext {
        RenderContext()
            .setting(ThemeKey.self, to: theme)
            .setting(MaxWidthKey.self, to: maxWidth)
    }
}
```

#### 核心 Keys（框架提供）

```swift
// MARK: - 核心 Keys

/// 主题样式
public enum ThemeKey: ContextKey {
    public static var defaultValue: MarkdownTheme { .default }
}

/// 最大宽度
public enum MaxWidthKey: ContextKey {
    public static var defaultValue: CGFloat { .greatestFiniteMagnitude }
}

/// 当前缩进（累积计算）
public enum IndentKey: ContextKey {
    public static var defaultValue: CGFloat { 0 }
}

/// Fragment ID 路径前缀
public enum PathPrefixKey: ContextKey {
    public static var defaultValue: String { "" }
}

/// 列表嵌套深度
public enum ListDepthKey: ContextKey {
    public static var defaultValue: Int { 0 }
}

/// 引用块嵌套深度
public enum BlockQuoteDepthKey: ContextKey {
    public static var defaultValue: Int { 0 }
}
```

#### 便捷访问器

```swift
// MARK: - 便捷访问器

extension RenderContext {
    
    // 读取
    public var theme: MarkdownTheme { self[ThemeKey.self] }
    public var maxWidth: CGFloat { self[MaxWidthKey.self] }
    public var indent: CGFloat { self[IndentKey.self] }
    public var pathPrefix: String { self[PathPrefixKey.self] }
    public var listDepth: Int { self[ListDepthKey.self] }
    public var blockQuoteDepth: Int { self[BlockQuoteDepthKey.self] }
    
    // 便捷修改
    public func addingIndent(_ delta: CGFloat) -> RenderContext {
        setting(IndentKey.self, to: indent + delta)
    }
    
    public func appendingPath(_ component: String) -> RenderContext {
        let newPath = pathPrefix.isEmpty ? component : "\(pathPrefix)_\(component)"
        return setting(PathPrefixKey.self, to: newPath)
    }
    
    public func enteringList() -> RenderContext {
        self.addingIndent(theme.list.nestingIndent)
            .setting(ListDepthKey.self, to: listDepth + 1)
    }
    
    public func enteringBlockQuote() -> RenderContext {
        self.addingIndent(theme.blockQuote.nestingIndent)
            .setting(BlockQuoteDepthKey.self, to: blockQuoteDepth + 1)
    }
    
    /// 生成 Fragment ID
    public func fragmentId(nodeType: String, index: Int) -> String {
        let component = "\(nodeType)_\(index)"
        return pathPrefix.isEmpty ? component : "\(pathPrefix)_\(component)"
    }
}
```

#### 核心 Key 清单

| Key | 类型 | 默认值 | 用途 |
|---|---|---|---|
| `ThemeKey` | `MarkdownTheme` | `.default` | 样式主题 |
| `MaxWidthKey` | `CGFloat` | `∞` | 最大宽度 |
| `IndentKey` | `CGFloat` | `0` | 当前缩进（累积） |
| `PathPrefixKey` | `String` | `""` | Fragment ID 前缀 |
| `ListDepthKey` | `Int` | `0` | 列表嵌套深度 |
| `BlockQuoteDepthKey` | `Int` | `0` | 引用块嵌套深度 |

**这些是最小核心**。其他信息：
- 从**节点本身**获取（如 `listItem.indexInParent`、`orderedList.startIndex`）
- 或**自定义 Key** 扩展

#### 新增 View 如何扩展 Context？

**场景**：新增 CollapsibleBlock，需要知道折叠嵌套深度

```swift
// 1. 定义自己的 Key（不改 RenderContext 结构！）
public enum CollapsibleDepthKey: ContextKey {
    public static var defaultValue: Int { 0 }
}

// 2. 添加便捷访问器（可选）
extension RenderContext {
    public var collapsibleDepth: Int { self[CollapsibleDepthKey.self] }
    
    public func enteringCollapsible() -> RenderContext {
        setting(CollapsibleDepthKey.self, to: collapsibleDepth + 1)
    }
}

// 3. 在渲染器中使用
struct CollapsibleBlockRenderer: NodeRenderer {
    func render(node: Markup, context: RenderContext, children: () -> [RenderFragment]) -> [RenderFragment] {
        let depth = context.collapsibleDepth
        let childContext = context.enteringCollapsible()
        // ...
    }
}
```

**新增 View 完全不需要改 RenderContext 的定义！**

#### 使用示例

```swift
// ListRenderer
struct ListRenderer: NodeRenderer {
    func render(node: Markup, context: RenderContext, children: () -> [RenderFragment]) -> [RenderFragment] {
        guard let list = node as? UnorderedList else { return [] }
        
        // 进入列表
        let listContext = context.enteringList()
        
        // 渲染子项
        var fragments: [RenderFragment] = []
        for (index, item) in list.listItems.enumerated() {
            let itemContext = listContext.appendingPath("item_\(index)")
            fragments.append(contentsOf: renderNode(item, context: itemContext))
        }
        
        return fragments
    }
}

// ListItemRenderer
struct ListItemRenderer: NodeRenderer {
    func render(node: Markup, context: RenderContext, children: () -> [RenderFragment]) -> [RenderFragment] {
        guard let listItem = node as? ListItem else { return [] }
        
        // 从节点本身获取索引（不是从 Context！）
        let index = listItem.indexInParent
        
        // 从父节点获取列表类型和起始序号
        let prefix: String
        if let orderedList = listItem.parent as? OrderedList {
            let startNumber = orderedList.startIndex
            prefix = "\(startNumber + UInt(index)). "
        } else if listItem.checkbox != nil {
            prefix = listItem.checkbox == .checked ? "☑ " : "☐ "
        } else {
            prefix = "• "
        }
        
        // 生成 Fragment ID
        let fragmentId = context.fragmentId(nodeType: "para", index: 0)
        
        // ...
    }
}
```

**关键点**：`listItemIndex` 从**节点本身**获取（`listItem.indexInParent`），不需要放在 Context 中！

### 4. 核心渲染引擎

```swift
/// Markdown 渲染引擎
public struct MarkdownRenderEngine {
    private let registry: RendererRegistry
    private let theme: MarkdownTheme
    private let configuration: MarkdownConfiguration
    
    /// 渲染文档（支持流式模式）
    public func render(_ text: String, mode: RenderMode = .normal) -> MarkdownRenderResult {
        // 流式模式：预处理补全未闭合标记
        let processedText = (mode == .streaming)
            ? MarkdownPreprocessor.preclose(text)
            : text
        
        let document = Document(parsing: processedText)
        
        // 使用 Environment 模式初始化 Context
        let context = RenderContext.initial(
            theme: theme,
            maxWidth: configuration.maxWidth
        )
        
        let fragments = renderNode(document, context: context)
        let optimized = optimizeFragments(fragments)
        
        return MarkdownRenderResult(fragments: optimized)
    }
    
    /// 递归渲染节点（核心）
    private func renderNode(_ node: Markup, context: RenderContext) -> [RenderFragment] {
        let nodeType = MarkdownNodeType(from: node)
        let renderer = resolveRenderer(for: nodeType, node: node)
        
        // Context 的修改由各 Renderer 自己负责
        return renderer.render(
            node: node,
            context: context,
            children: { [self] in
                node.children.flatMap { child in
                    // 子节点的 path 由渲染器传递
                    self.renderNode(child, context: context)
                }
            }
        )
    }
}

public enum RenderMode {
    case normal
    case streaming  // 启用预处理
}
```

---

## 流式动画系统

### 核心问题

> **如何保证新数据到达时，动画从当前位置继续，而不是重置？**

这是流式动画的核心挑战。我们需要解决：
1. 逐字动画如何实现？
2. 新数据到达时如何保持动画连续？
3. 内容被修改时如何处理？

---

### 逐字动画技术方案

#### 方案对比

| 方案 | 实现 | 优点 | 缺点 |
|---|---|---|---|
| **A. Substring** | `attributedText.attributedSubstring(from: 0..<length)` | 简单、可靠 | 每帧创建新对象 |
| **B. Alpha 控制** | 每个字符设置不同 alpha | 可实现渐入效果 | 复杂、性能差 |
| **C. Mask 遮罩** | CAGradientLayer mask | 视觉效果好 | 多行文本难处理 |

**推荐方案 A**：简单可靠，性能足够（UILabel 的 attributedText 设置本身很快）。

#### 方案 A 实现

```swift
/// 逐字显示的核心实现
func setDisplayedContentLength(_ length: Int) {
    let safeLength = min(max(0, length), fullAttributedText.length)
    _displayedContentLength = safeLength
    
    if safeLength == 0 {
        contentLabel.attributedText = nil
    } else {
        // 取前 N 个字符
        let range = NSRange(location: 0, length: safeLength)
        contentLabel.attributedText = fullAttributedText.attributedSubstring(from: range)
    }
}
```

---

### 动画进度不中断的关键设计

#### 问题场景

```
时刻 T1：显示 "Hello "，动画进度 displayedLength = 4（显示 "Hell"）
时刻 T2：新数据到达，内容变为 "Hello World"
期望：动画从 "Hell" 继续，显示 "Hello"..."Hello World"
错误：动画重置，从 "H" 重新开始
```

#### 解决方案：三层保障

```
┌─────────────────────────────────────────────────────────────────┐
│ 层 1：稳定的 Fragment ID                                         │
│                                                                  │
│ Fragment ID 基于【结构位置】而非【内容】                          │
│                                                                  │
│ ✅ "root_list_0_item_1_codeBlock_0" - 内容变化，ID 不变          │
│ ❌ content.hashValue - 内容变化，ID 就变                          │
│                                                                  │
│ 意义：Diff 能识别为 update 而非 delete + insert                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 层 2：View 复用 + 数据/进度分离                                   │
│                                                                  │
│ View 内部状态：                                                   │
│ ├── fullContent: 完整内容（会更新）                               │
│ └── displayedLength: 显示进度（不随 fullContent 更新而重置）       │
│                                                                  │
│ updateContent() 只更新 fullContent，不改变 displayedLength        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 层 3：AnimationController 只更新目标，不重置进度                   │
│                                                                  │
│ 状态：                                                            │
│ ├── targetProgress[fragmentId] = 目标进度（会更新）               │
│ └── currentPlayingIndex = 当前播放位置（不重置）                   │
│                                                                  │
│ handleUpdate() 只更新 targetProgress，动画自然继续                │
└─────────────────────────────────────────────────────────────────┘
```

#### 完整流程图

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
时刻 T1：初始状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fragment:
  fragmentId = "root_codeBlock_0"
  content = "Hello "

CodeBlockView:
  fullAttributedText = "Hello "
  displayedLength = 4

AnimationController:
  targetProgress["root_codeBlock_0"] = 6
  currentPlayingIndex = 0

用户看到: "Hell" (动画进行中)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
时刻 T2：新数据到达
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 渲染层输出新 Fragment:
   fragmentId = "root_codeBlock_0"  ← ID 不变！
   content = "Hello World"

2. Diff 层识别为 update（因为 ID 相同）:
   .update(old: fragment1, new: fragment2)

3. ContainerView 复用 View，调用 updateContent:
   let result = codeBlockView.updateContent("Hello World")
   
4. CodeBlockView.updateContent():
   - fullAttributedText = "Hello World"  ← 更新
   - displayedLength = 4                  ← 不变！
   - return .append(addedCount: 5)

5. AnimationController.handleUpdate():
   - targetProgress["root_codeBlock_0"] = 11  ← 更新
   - currentPlayingIndex = 0                   ← 不变！

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
时刻 T3+：动画继续
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

tick(): displayedLength = 4, target = 11
  → setDisplayedContentLength(7)
  → 用户看到: "Hello W"

tick(): displayedLength = 7, target = 11
  → setDisplayedContentLength(10)
  → 用户看到: "Hello Worl"

tick(): displayedLength = 10, target = 11
  → setDisplayedContentLength(11)
  → 用户看到: "Hello World"
  → 完成，currentPlayingIndex++

整个过程无闪烁、无中断！
```

---

### 内容修改的处理

#### 场景

```
T1: fullContent = "Hello World", displayedLength = 8 (显示 "Hello Wo")
T2: fullContent = "Hello Earth" (用户修改了之前的内容)
```

#### 检测修改

```swift
func analyzeChange(old: String, new: String) -> ContentUpdateResult {
    // 找公共前缀
    let commonPrefixLength = zip(old, new)
        .prefix(while: { $0 == $1 })
        .count
    
    // "Hello World" vs "Hello Earth"
    // 公共前缀: "Hello " (6 个字符)
    
    if commonPrefixLength == old.count {
        // 纯追加
        return .append(addedCount: new.count - old.count)
    } else {
        // 有修改
        return .modified(unchangedPrefixLength: commonPrefixLength)
    }
}
```

#### 处理修改

```swift
func handleUpdate(fragmentId: String, result: ContentUpdateResult) {
    switch result.type {
    case .append(_):
        // 纯追加：只更新目标
        targetProgress[fragmentId] = result.currentLength
        
    case .modified(let unchangedPrefixLength):
        // 有修改：检查是否需要回退
        if let view = views[fragmentId] {
            if view.displayedContentLength > unchangedPrefixLength {
                // 已显示的部分被修改了，回退到安全位置
                view.setDisplayedContentLength(unchangedPrefixLength)
            }
        }
        targetProgress[fragmentId] = result.currentLength
        
    case .truncated(let newLength):
        // 被截短：回退到新长度
        if let view = views[fragmentId] {
            if view.displayedContentLength > newLength {
                view.setDisplayedContentLength(newLength)
            }
        }
        targetProgress[fragmentId] = newLength
        
    case .unchanged:
        break
    }
}
```

#### 修改场景的流程

```
T1: "Hello World", displayed = 8, target = 11

T2: 内容变为 "Hello Earth"
    - commonPrefixLength = 6 ("Hello ")
    - displayed = 8 > 6，需要回退
    - setDisplayedContentLength(6)  ← 立即回退
    - targetProgress = 11

T3+: 动画继续
    - displayed = 6 → 9 → 11
    - 用户看到: "Hello " → "Hello Ear" → "Hello Earth"
```

---

### 1. AnimatableContent 协议（核心）

```swift
/// View 动画能力协议
public protocol AnimatableContent: UIView {
    
    // MARK: - 进入动画
    
    /// 进入动画配置（nil 表示无进入动画）
    var enterAnimationConfig: EnterAnimationConfig? { get }
    
    // MARK: - 内容动画
    
    /// 内容动画配置（nil 表示无内容动画，如图片）
    var contentAnimationConfig: ContentAnimationConfig? { get }
    
    /// 当前显示进度
    var displayedContentLength: Int { get }
    
    /// 总内容长度
    var totalContentLength: Int { get }
    
    /// 设置显示进度
    func setDisplayedContentLength(_ length: Int)
    
    // MARK: - 内容更新
    
    /// 更新完整内容，返回变化信息
    func updateContent(_ content: Any) -> ContentUpdateResult
}
```

### 2. 配置结构

```swift
public struct EnterAnimationConfig {
    public let duration: TimeInterval
    public let type: EnterAnimationType
    public let blocksSubsequent: Bool  // 是否阻塞后续动画
    
    public enum EnterAnimationType {
        case fadeIn
        case slideUp
        case expand
        case custom((UIView, @escaping () -> Void) -> Void)
    }
    
    // 预置配置
    public static let `default` = EnterAnimationConfig(
        duration: 0.2, type: .fadeIn, blocksSubsequent: true
    )
    public static let quickFadeIn = EnterAnimationConfig(
        duration: 0.15, type: .fadeIn, blocksSubsequent: false
    )
    public static let expand = EnterAnimationConfig(
        duration: 0.25, type: .expand, blocksSubsequent: true
    )
}

public struct ContentAnimationConfig {
    public let speedMultiplier: CGFloat  // 速率倍率（1.0 = 默认）
    public let granularity: AnimationGranularity
    
    public enum AnimationGranularity {
        case character   // 逐字符
        case word        // 逐词
        case line        // 逐行
    }
    
    // 预置配置
    public static let text = ContentAnimationConfig(speedMultiplier: 1.0, granularity: .character)
    public static let code = ContentAnimationConfig(speedMultiplier: 1.5, granularity: .character)
    public static let thinking = ContentAnimationConfig(speedMultiplier: 0.8, granularity: .character)
}

public struct ContentUpdateResult {
    public enum UpdateType {
        case unchanged
        case append(addedCount: Int)
        case modified(unchangedPrefixLength: Int)
        case truncated(newLength: Int)
    }
    
    public let type: UpdateType
    public let previousLength: Int
    public let currentLength: Int
}
```

### 3. 协议默认实现（替代基类）

```swift
// MARK: - 文字类 View 的默认实现

/// 文字内容存储协议
public protocol TextContentStorage: AnyObject {
    var fullAttributedText: NSAttributedString { get set }
    var previousPlainText: String { get set }
    var _displayedContentLength: Int { get set }
    var contentLabel: UILabel { get }
}

/// 为 TextContentStorage 提供默认的 AnimatableContent 实现
extension AnimatableContent where Self: TextContentStorage {
    
    public var displayedContentLength: Int { _displayedContentLength }
    public var totalContentLength: Int { fullAttributedText.length }
    
    public func setDisplayedContentLength(_ length: Int) {
        let safeLength = min(max(0, length), fullAttributedText.length)
        _displayedContentLength = safeLength
        
        if safeLength == 0 {
            contentLabel.attributedText = nil
        } else {
            let range = NSRange(location: 0, length: safeLength)
            contentLabel.attributedText = fullAttributedText.attributedSubstring(from: range)
        }
    }
    
    public func updateContent(_ content: Any) -> ContentUpdateResult {
        guard let newText = content as? NSAttributedString else {
            return ContentUpdateResult(type: .unchanged, previousLength: 0, currentLength: 0)
        }
        
        let newPlainText = newText.string
        let oldPlainText = previousPlainText
        let oldLength = oldPlainText.count
        let newLength = newPlainText.count
        
        // 更新存储
        fullAttributedText = newText
        previousPlainText = newPlainText
        
        // 分析变化
        if oldPlainText == newPlainText {
            return ContentUpdateResult(type: .unchanged, previousLength: oldLength, currentLength: newLength)
        }
        
        let commonPrefixLength = zip(oldPlainText, newPlainText)
            .prefix(while: { $0 == $1 })
            .count
        
        if commonPrefixLength == oldLength {
            return ContentUpdateResult(
                type: .append(addedCount: newLength - oldLength),
                previousLength: oldLength,
                currentLength: newLength
            )
        } else {
            return ContentUpdateResult(
                type: .modified(unchangedPrefixLength: commonPrefixLength),
                previousLength: oldLength,
                currentLength: newLength
            )
        }
    }
}

// MARK: - 表格类 View 的默认实现

/// 表格内容存储协议
public protocol TableContentStorage: AnyObject {
    var fullTableData: [[String]] { get set }
    var previousLinearText: String { get set }
    var _displayedContentLength: Int { get set }
    func cellLabel(row: Int, col: Int) -> UILabel?
}

extension AnimatableContent where Self: TableContentStorage {
    
    public var displayedContentLength: Int { _displayedContentLength }
    
    public var totalContentLength: Int {
        fullTableData.flatMap { $0 }.joined(separator: " ").count
    }
    
    public func setDisplayedContentLength(_ length: Int) {
        _displayedContentLength = min(max(0, length), totalContentLength)
        renderCells(upToCharacter: _displayedContentLength)
    }
    
    private func renderCells(upToCharacter charCount: Int) {
        var remaining = charCount
        
        for (rowIndex, row) in fullTableData.enumerated() {
            for (colIndex, cellText) in row.enumerated() {
                guard let label = cellLabel(row: rowIndex, col: colIndex) else { continue }
                
                if remaining <= 0 {
                    label.text = ""
                } else if remaining >= cellText.count {
                    label.text = cellText
                    remaining -= cellText.count + 1
                } else {
                    label.text = String(cellText.prefix(remaining))
                    remaining = 0
                }
            }
        }
    }
    
    public func updateContent(_ content: Any) -> ContentUpdateResult {
        guard let newData = content as? [[String]] else {
            return ContentUpdateResult(type: .unchanged, previousLength: 0, currentLength: 0)
        }
        
        let newLinear = newData.flatMap { $0 }.joined(separator: " ")
        let oldLinear = previousLinearText
        
        fullTableData = newData
        previousLinearText = newLinear
        
        // 分析变化（同文字逻辑）
        if oldLinear == newLinear {
            return ContentUpdateResult(type: .unchanged, previousLength: oldLinear.count, currentLength: newLinear.count)
        }
        
        let commonPrefixLength = zip(oldLinear, newLinear).prefix(while: { $0 == $1 }).count
        
        if commonPrefixLength == oldLinear.count {
            return ContentUpdateResult(
                type: .append(addedCount: newLinear.count - oldLinear.count),
                previousLength: oldLinear.count,
                currentLength: newLinear.count
            )
        } else {
            return ContentUpdateResult(
                type: .modified(unchangedPrefixLength: commonPrefixLength),
                previousLength: oldLinear.count,
                currentLength: newLinear.count
            )
        }
    }
}

// MARK: - 纯展示 View 的默认实现

/// 纯展示内容协议（无内容动画）
public protocol DisplayOnlyContent {}

extension AnimatableContent where Self: DisplayOnlyContent {
    public var displayedContentLength: Int { 0 }
    public var totalContentLength: Int { 0 }
    public var contentAnimationConfig: ContentAnimationConfig? { nil }
    
    public func setDisplayedContentLength(_ length: Int) {
        // 空实现
    }
    
    public func updateContent(_ content: Any) -> ContentUpdateResult {
        return ContentUpdateResult(type: .unchanged, previousLength: 0, currentLength: 0)
    }
}
```

### 4. 具体 View 实现（非常简洁）

```swift
// MARK: - CodeBlockView

final class CodeBlockView: UIView, AnimatableContent, TextContentStorage {
    
    // TextContentStorage 要求
    var fullAttributedText: NSAttributedString = NSAttributedString()
    var previousPlainText: String = ""
    var _displayedContentLength: Int = 0
    lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        addSubview(label)
        return label
    }()
    
    // 只需要配置这两个属性
    var enterAnimationConfig: EnterAnimationConfig? { .default }
    var contentAnimationConfig: ContentAnimationConfig? { .code }
    
    // UI 相关
    private let languageLabel = UILabel()
    private let copyButton = UIButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 8
        // ... 布局代码
    }
}

// MARK: - TableView

final class MarkdownTableView: UIView, AnimatableContent, TableContentStorage {
    
    // TableContentStorage 要求
    var fullTableData: [[String]] = []
    var previousLinearText: String = ""
    var _displayedContentLength: Int = 0
    private var cellLabels: [[UILabel]] = []
    
    func cellLabel(row: Int, col: Int) -> UILabel? {
        guard row < cellLabels.count, col < cellLabels[row].count else { return nil }
        return cellLabels[row][col]
    }
    
    // 只需要配置
    var enterAnimationConfig: EnterAnimationConfig? { .expand }
    var contentAnimationConfig: ContentAnimationConfig? {
        ContentAnimationConfig(speedMultiplier: 1.2, granularity: .character)
    }
}

// MARK: - ImageView

final class MarkdownImageView: UIView, AnimatableContent, DisplayOnlyContent {
    
    private let imageView = UIImageView()
    
    // 只需要配置进入动画
    var enterAnimationConfig: EnterAnimationConfig? {
        EnterAnimationConfig(duration: 0.3, type: .fadeIn, blocksSubsequent: false)
    }
    
    func configure(image: UIImage?) {
        imageView.image = image
    }
}
```

### 5. AnimationController（目标进度模式）

```swift
/// 动画控制器
public final class AnimationController {
    
    // MARK: - 状态
    
    /// 每个 fragment 的目标进度
    private var targetProgress: [String: Int] = [:]
    
    /// fragment 的顺序
    private var fragmentOrder: [String] = []
    
    /// 当前正在播放的 fragment index
    private var currentPlayingIndex: Int = 0
    
    /// View 引用
    private var views: [String: AnimatableContent] = [:]
    private var textLabels: [String: UILabel] = [:]
    
    /// 已播放进入动画的 View
    private var enteredViews: Set<String> = []
    
    /// 暂停状态（View 进入动画期间）
    private var isPaused: Bool = false
    
    /// DisplayLink
    private var displayLink: CADisplayLink?
    
    // MARK: - 配置
    
    public var baseCharsPerFrame: Int = 3
    
    // MARK: - 处理 Fragment 变化
    
    public func handleInsert(fragmentId: String, view: UIView, at index: Int) {
        fragmentOrder.insert(fragmentId, at: index)
        
        if let animatable = view as? AnimatableContent {
            views[fragmentId] = animatable
            targetProgress[fragmentId] = animatable.totalContentLength
            animatable.setDisplayedContentLength(0)
        } else if let label = view as? UILabel {
            textLabels[fragmentId] = label
            targetProgress[fragmentId] = label.attributedText?.length ?? 0
        }
        
        startDisplayLinkIfNeeded()
    }
    
    public func handleUpdate(fragmentId: String, updateResult: ContentUpdateResult) {
        switch updateResult.type {
        case .unchanged:
            break
            
        case .append(_):
            targetProgress[fragmentId] = updateResult.currentLength
            
        case .modified(let unchangedPrefixLength):
            // 回退到安全位置
            if let view = views[fragmentId] {
                if view.displayedContentLength > unchangedPrefixLength {
                    view.setDisplayedContentLength(unchangedPrefixLength)
                }
            }
            targetProgress[fragmentId] = updateResult.currentLength
            recalculateCurrentPlayingIndex()
            
        case .truncated(let newLength):
            if let view = views[fragmentId] {
                if view.displayedContentLength > newLength {
                    view.setDisplayedContentLength(newLength)
                }
            }
            targetProgress[fragmentId] = newLength
        }
        
        startDisplayLinkIfNeeded()
    }
    
    public func handleDelete(fragmentId: String) {
        views.removeValue(forKey: fragmentId)
        textLabels.removeValue(forKey: fragmentId)
        fragmentOrder.removeAll { $0 == fragmentId }
        targetProgress.removeValue(forKey: fragmentId)
        enteredViews.remove(fragmentId)
        recalculateCurrentPlayingIndex()
    }
    
    // MARK: - 动画执行
    
    @objc private func tick() {
        guard !isPaused else { return }
        guard currentPlayingIndex < fragmentOrder.count else {
            stopDisplayLink()
            return
        }
        
        let fragmentId = fragmentOrder[currentPlayingIndex]
        
        if let view = views[fragmentId] {
            tickAnimatableView(fragmentId: fragmentId, view: view)
        } else if let label = textLabels[fragmentId] {
            tickTextLabel(fragmentId: fragmentId, label: label)
        } else {
            currentPlayingIndex += 1
        }
    }
    
    private func tickAnimatableView(fragmentId: String, view: AnimatableContent) {
        guard let target = targetProgress[fragmentId] else {
            currentPlayingIndex += 1
            return
        }
        
        // 处理进入动画
        if !enteredViews.contains(fragmentId) {
            if let config = view.enterAnimationConfig {
                enteredViews.insert(fragmentId)
                
                if config.blocksSubsequent {
                    isPaused = true
                    playEnterAnimation(view, config: config) { [weak self] in
                        self?.isPaused = false
                    }
                    return
                } else {
                    playEnterAnimation(view, config: config, completion: nil)
                }
            } else {
                enteredViews.insert(fragmentId)
            }
        }
        
        // 处理内容动画
        let current = view.displayedContentLength
        
        if current < target {
            let speedMultiplier = view.contentAnimationConfig?.speedMultiplier ?? 1.0
            let step = Int(ceil(CGFloat(baseCharsPerFrame) * speedMultiplier))
            let newLength = min(current + step, target)
            view.setDisplayedContentLength(newLength)
        }
        
        // 检查是否完成（使用最新 target）
        if let latestTarget = targetProgress[fragmentId],
           view.displayedContentLength >= latestTarget {
            currentPlayingIndex += 1
        }
    }
    
    private func tickTextLabel(fragmentId: String, label: UILabel) {
        // TextFragment 的简单逐字动画
        guard let target = targetProgress[fragmentId],
              let fullText = label.attributedText else {
            currentPlayingIndex += 1
            return
        }
        
        // TODO: 需要额外存储 TextFragment 的显示进度
        currentPlayingIndex += 1
    }
    
    private func recalculateCurrentPlayingIndex() {
        for (index, fragmentId) in fragmentOrder.enumerated() {
            guard let target = targetProgress[fragmentId] else { continue }
            
            var currentDisplayed = 0
            if let view = views[fragmentId] {
                currentDisplayed = view.displayedContentLength
            }
            
            if currentDisplayed < target {
                currentPlayingIndex = index
                return
            }
        }
        currentPlayingIndex = fragmentOrder.count
    }
    
    // MARK: - 进入动画
    
    private func playEnterAnimation(_ view: AnimatableContent, config: EnterAnimationConfig, completion: (() -> Void)?) {
        switch config.type {
        case .fadeIn:
            view.alpha = 0
            UIView.animate(withDuration: config.duration, animations: {
                view.alpha = 1
            }, completion: { _ in completion?() })
            
        case .slideUp:
            view.transform = CGAffineTransform(translationX: 0, y: 20)
            view.alpha = 0
            UIView.animate(withDuration: config.duration, animations: {
                view.transform = .identity
                view.alpha = 1
            }, completion: { _ in completion?() })
            
        case .expand:
            view.clipsToBounds = true
            let targetHeight = view.frame.height
            view.frame.size.height = 0
            UIView.animate(withDuration: config.duration, animations: {
                view.frame.size.height = targetHeight
            }, completion: { _ in completion?() })
            
        case .custom(let animator):
            animator(view) { completion?() }
        }
    }
    
    // MARK: - DisplayLink 管理
    
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - 快进
    
    public func skipToEnd() {
        for fragmentId in fragmentOrder {
            if let view = views[fragmentId], let target = targetProgress[fragmentId] {
                view.setDisplayedContentLength(target)
                if !enteredViews.contains(fragmentId) {
                    enteredViews.insert(fragmentId)
                    view.alpha = 1
                }
            }
        }
        currentPlayingIndex = fragmentOrder.count
        stopDisplayLink()
    }
}
```

---

## 数据流设计

### 非流式渲染

```
text ──► MarkdownKit.render() ──► [Fragment]
                                      │
                                      ▼
                          ContainerView.apply([Fragment])
                                      │
                                      ▼
                              创建 View + 立即显示完整内容
```

### 流式渲染

```
chunk ──► StreamingBuffer ──► 节流触发 ──► MarkdownKit.render(mode: .streaming)
                                                    │
                                                    ▼
                                              [Fragment]
                                                    │
                   ┌────────────────────────────────┴────────────────────────────────┐
                   │                                                                  │
                   ▼                                                                  ▼
         Differ.diff(old, new)                                    ContainerView 保存 old 结果
                   │
                   ▼
             [Change]
                   │
                   ▼
    ContainerView.applyDiff([Fragment], [Change])
                   │
                   ▼
         AnimationController
         ├── insert → handleInsert（设置 target，启动动画）
         ├── update → handleUpdate（更新 target，可能回退）
         └── delete → handleDelete（播放退出动画）
                   │
                   ▼
         每帧 tick()
         ├── 顺序播放每个 fragment
         ├── View 进入动画（可阻塞）
         ├── 内容逐字动画（目标进度趋近）
         └── 完成后移动到下一个
```

---

## Fragment ID 策略

```swift
public enum FragmentIdStrategy {
    /// 结构指纹（默认）：基于节点类型 + 位置路径
    /// 内容变化时 ID 不变，支持增量更新
    case structuralFingerprint
    
    /// 顺序索引（降级）：基于遍历顺序递增
    /// 简单可靠，但内容变化会导致后续 ID 全变
    case sequentialIndex
}

// 生成 ID 示例
// structuralFingerprint: "root_list_0_item_1_codeBlock_0"
// sequentialIndex: "fragment_5"
```

---

## 未闭合标记预处理

```swift
/// 流式过程中 Markdown 经常不完整
/// 预闭合确保渲染结果始终是"当前文本的最佳呈现"
public struct MarkdownPreprocessor {
    
    /// 单次 O(n) 扫描，补全未闭合标记
    public static func preclose(_ text: String) -> String {
        var result = text
        var inCodeFence = false
        var inInlineCode = false
        
        // 单次扫描检测状态
        var i = text.startIndex
        while i < text.endIndex {
            let remaining = text[i...]
            
            if remaining.hasPrefix("```") {
                inCodeFence.toggle()
                i = text.index(i, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
            } else if remaining.hasPrefix("`") && !inCodeFence {
                inInlineCode.toggle()
                i = text.index(after: i)
            } else {
                i = text.index(after: i)
            }
        }
        
        // 根据最终状态补全
        if inCodeFence {
            result += "\n```"
        }
        if inInlineCode {
            result += "`"
        }
        
        return result
    }
}
```

---

## Fragment Diff 算法

```swift
public enum FragmentChange {
    case insert(fragment: RenderFragment, at: Int)
    case update(old: RenderFragment, new: RenderFragment, at: Int)
    case delete(fragment: RenderFragment, at: Int)
}

public struct FragmentDiffer {
    
    /// 快速路径：检测是否只有尾部 append
    public static func tryFastAppendDiff(
        old: [RenderFragment],
        new: [RenderFragment]
    ) -> [FragmentChange]? {
        guard new.count >= old.count else { return nil }
        
        for i in 0..<old.count {
            if old[i].fragmentId != new[i].fragmentId {
                return nil
            }
        }
        
        // 检查是否有内容更新
        var changes: [FragmentChange] = []
        for i in 0..<old.count {
            if !contentEquals(old[i], new[i]) {
                changes.append(.update(old: old[i], new: new[i], at: i))
            }
        }
        
        // 追加新增
        for i in old.count..<new.count {
            changes.append(.insert(fragment: new[i], at: i))
        }
        
        return changes
    }
    
    /// 完整 diff
    public static func diff(
        old: [RenderFragment],
        new: [RenderFragment]
    ) -> [FragmentChange] {
        if let fast = tryFastAppendDiff(old: old, new: new) {
            return fast
        }
        
        // 基于 fragmentId 的完整 diff
        // ...
    }
}
```

---

## MarkdownContainerView 完整设计

```swift
public final class MarkdownContainerView: UIView {
    
    // MARK: - 状态
    
    private(set) var renderResult: MarkdownRenderResult?
    private var fragmentViews: [String: UIView] = [:]
    private var fragmentFrames: [String: CGRect] = [:]
    private var reusePool: [String: [UIView]] = [:]
    private(set) var contentHeight: CGFloat = 0
    
    // MARK: - 组件
    
    private let animationController = AnimationController()
    
    // MARK: - 回调
    
    public var onContentHeightChanged: ((CGFloat) -> Void)?
    
    // MARK: - 全量应用（非流式）
    
    public func apply(_ result: MarkdownRenderResult, maxWidth: CGFloat) {
        self.renderResult = result
        calculateFrames(for: result.fragments, maxWidth: maxWidth)
        
        // 立即创建并显示所有 View（无动画）
        for fragment in result.fragments {
            let view = createOrReuseView(for: fragment)
            view.frame = fragmentFrames[fragment.fragmentId] ?? .zero
            configureView(view, with: fragment, animate: false)
        }
        
        onContentHeightChanged?(contentHeight)
    }
    
    // MARK: - 增量应用（流式）
    
    public func applyDiff(
        _ result: MarkdownRenderResult,
        changes: [FragmentChange],
        maxWidth: CGFloat
    ) {
        let oldHeight = contentHeight
        self.renderResult = result
        calculateFrames(for: result.fragments, maxWidth: maxWidth)
        
        for change in changes {
            switch change {
            case .insert(let fragment, let index):
                let view = createOrReuseView(for: fragment)
                view.frame = fragmentFrames[fragment.fragmentId] ?? .zero
                configureView(view, with: fragment, animate: true)
                animationController.handleInsert(
                    fragmentId: fragment.fragmentId,
                    view: view,
                    at: index
                )
                
            case .update(_, let new, _):
                guard let view = fragmentViews[new.fragmentId] else { continue }
                
                // 更新内容并获取变化
                if let animatable = view as? AnimatableContent,
                   let viewFrag = new as? ViewFragment {
                    let updateResult = animatable.updateContent(viewFrag.content)
                    animationController.handleUpdate(
                        fragmentId: new.fragmentId,
                        updateResult: updateResult
                    )
                }
                
                // 更新 frame
                if let newFrame = fragmentFrames[new.fragmentId] {
                    UIView.animate(withDuration: 0.2) {
                        view.frame = newFrame
                    }
                }
                
            case .delete(let fragment, _):
                guard let view = fragmentViews.removeValue(forKey: fragment.fragmentId) else { continue }
                animationController.handleDelete(fragmentId: fragment.fragmentId)
                
                // 退出动画
                UIView.animate(withDuration: 0.2, animations: {
                    view.alpha = 0
                }, completion: { _ in
                    view.removeFromSuperview()
                    self.recycleView(view, reuseId: (fragment as? ViewFragment)?.reuseIdentifier ?? "text")
                })
            }
        }
        
        if contentHeight != oldHeight {
            onContentHeightChanged?(contentHeight)
        }
    }
    
    // MARK: - 私有方法
    
    private func configureView(_ view: UIView, with fragment: RenderFragment, animate: Bool) {
        if animate {
            // 流式场景：初始显示为空，等动画控制器调度
            if let animatable = view as? AnimatableContent {
                animatable.setDisplayedContentLength(0)
            }
        } else {
            // 非流式场景：立即显示完整内容
            if let animatable = view as? AnimatableContent {
                animatable.setDisplayedContentLength(animatable.totalContentLength)
            }
        }
    }
    
    // MARK: - 快进
    
    public func skipAnimation() {
        animationController.skipToEnd()
    }
}
```

---

## 迁移计划

### Phase 1: 核心引擎（1-2小时）
1. 创建 `MarkdownRenderEngine`
2. 实现 `renderNode` 递归逻辑
3. 实现 `RenderContext` 传递
4. 实现 `MarkdownPreprocessor` 预处理

### Phase 2: 默认渲染器（2-3小时）
1. 迁移所有 `visitXXX` 为独立 `XXXRenderer`
2. 实现 `NodeRenderer` 协议
3. 注册默认渲染器

### Phase 3: Fragment 优化（1小时）
1. 实现 `optimizeFragments`
2. 合并相邻 TextFragment
3. 处理空 Fragment

### Phase 4: 动画系统（2-3小时）
1. 实现 `AnimatableContent` 协议及默认实现
2. 实现 `AnimationController`
3. 迁移 CodeBlockView、TableView 等使用新协议

### Phase 5: Diff 系统（1小时）
1. 实现 `FragmentDiffer`
2. 实现快速路径（append-only）
3. 集成到 `MarkdownContainerView`

### Phase 6: 测试验证（1-2小时）
1. 运行所有边界 Case
2. 流式动画测试
3. 性能对比
4. 回归测试

### Phase 7: 清理（30分钟）
1. 移除旧的 `MarkdownRenderer`
2. 更新文档
3. 更新 Example

---

## 文件结构

```
Sources/XHSMarkdownKit/
├── Public/
│   ├── MarkdownKit.swift               # 主入口 API
│   ├── MarkdownConfiguration.swift     # 配置项
│   ├── MarkdownContainerView.swift     # 布局容器
│   └── MarkdownRenderable.swift        # 便捷渲染协议
│
├── Engine/
│   ├── MarkdownRenderEngine.swift      # 核心引擎
│   ├── RenderContext.swift             # 渲染上下文
│   ├── MarkdownPreprocessor.swift      # 未闭合标记预处理
│   └── FragmentOptimizer.swift         # Fragment 合并优化
│
├── Renderers/
│   ├── NodeRenderer.swift              # 渲染器协议
│   ├── RendererRegistry.swift          # 注册表
│   └── Defaults/
│       ├── ParagraphRenderer.swift
│       ├── HeadingRenderer.swift
│       ├── ListRenderer.swift
│       ├── CodeBlockRenderer.swift
│       ├── BlockQuoteRenderer.swift
│       ├── TableRenderer.swift
│       ├── ImageRenderer.swift
│       └── InlineRenderer.swift
│
├── Fragments/
│   ├── RenderFragment.swift            # Fragment 协议
│   ├── TextFragment.swift
│   ├── ViewFragment.swift
│   └── SpacingFragment.swift
│
├── Animation/
│   ├── AnimatableContent.swift         # 动画能力协议
│   ├── AnimationConfig.swift           # 动画配置
│   ├── AnimationController.swift       # 动画调度器
│   ├── TextContentStorage.swift        # 文字存储协议 + 默认实现
│   ├── TableContentStorage.swift       # 表格存储协议 + 默认实现
│   └── DisplayOnlyContent.swift        # 纯展示协议 + 默认实现
│
├── Streaming/
│   ├── StreamingTextBuffer.swift       # 文本缓冲 + 节流
│   └── FragmentDiffer.swift            # Fragment 差异比对
│
├── Views/
│   ├── CodeBlockView.swift
│   ├── MarkdownTableView.swift
│   ├── MarkdownImageView.swift
│   └── BlockQuoteView.swift
│
├── Cache/
│   └── DocumentCache.swift             # Document LRU 缓存
│
├── Theme/
│   └── MarkdownTheme.swift             # 样式 Token
│
└── Extensions/
    ├── NSAttributedString+Markdown.swift
    └── UIFont+Traits.swift
```

---

## 关键设计决策

| 决策 | 选择 | 理由 |
|---|---|---|
| **预处理位置** | Markdown 层内部 | 需要 Markdown 语法知识 |
| **动画速率控制** | UI 层（AnimationController） | 唯一理解动画的层 |
| **动画顺序** | 顺序执行 + View 动画阻塞 | 保证视觉连续性 |
| **进度管理** | 目标进度 + 每帧趋近 | 避免复杂的原子队列 |
| **内容修改处理** | 检测公共前缀 + 回退 | 保持动画连续 |
| **View 动画实现** | 协议 + 协议扩展 | 比基类更灵活，Swift 风格 |
| **协议默认实现** | 组合协议（TextContentStorage 等）| 代码复用，新 View 只需配置 |

---

## 总结

V2.1 架构的核心改进：

1. **四层清晰分离**：输入层 → Markdown 层 → Diff 层 → UI 层
2. **统一 Fragment 流**：所有 `render` 返回 `[RenderFragment]`，无状态
3. **目标进度动画**：不用原子队列，用目标进度 + 每帧趋近
4. **协议驱动扩展**：通过组合协议提供默认实现，新 View 只需几行配置
5. **完整流式支持**：预处理、Diff、顺序动画、内容修改处理

这样设计的库：
- **正确**：任意嵌套场景下顺序正确
- **高效**：O(1) 缩进计算，Fragment 自动优化
- **可扩展**：协议驱动，轻松自定义
- **流式友好**：完整的流式渲染 + 平滑动画支持
