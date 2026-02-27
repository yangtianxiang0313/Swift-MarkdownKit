# Fragment 外部状态管理 - 实施技术方案

> 基于 FRAGMENT_STATE_DESIGN.md 的细化实施计划

---

## 一、文件结构

```
Sources/XHSMarkdownKit/
├── State/
│   ├── FragmentState.swift           # FragmentState 协议
│   ├── FragmentStateStore.swift      # 状态存储
│   ├── States/
│   │   ├── CollapsedState.swift      # 折叠状态（预留）
│   │   └── CodeBlockInteractionState.swift  # 代码块交互状态（isCopied）
│   └── FragmentEvent.swift           # 事件协议
├── Protocols/
│   ├── FragmentView.swift            # 新增：静态高度计算协议
│   ├── FragmentConfigurable.swift    # 已有
│   └── DynamicHeightView.swift       # 移除，由 FragmentView 替代
├── Core/
│   └── ContextKeys.swift             # 新增 StateStoreKey
└── ... 其他文件
```

---

## 二、Phase 1：基础设施

### 2.1 新增文件

**FragmentState.swift**
```swift
public protocol FragmentState {
    static var stateType: String { get }
    static var defaultState: Self { get }
}
```

**FragmentStateStore.swift**
```swift
public final class FragmentStateStore {
    private var states: [String: [String: Any]] = [:]
    public var onStateChange: ((String) -> Void)?
    
    public func getState<S: FragmentState>(_ type: S.Type, for fragmentId: String) -> S
    public func updateState<S: FragmentState>(_ state: S, for fragmentId: String, triggerRender: Bool = true)
    public func clearState(for fragmentId: String)
    public func gc(existingIds: Set<String>)
}
```

**States/CodeBlockInteractionState.swift**
```swift
public struct CodeBlockInteractionState: FragmentState {
    public static var stateType: String { "codeBlockInteraction" }
    public static var defaultState: Self { CodeBlockInteractionState(isCopied: false) }
    public var isCopied: Bool
}
```

### 2.2 修改文件

**ContextKeys.swift**
- 新增 `StateStoreKey: ContextKey`，Value 类型为 `FragmentStateStore?`

**RenderContext.swift**
- `initial(theme:maxWidth:)` 增加可选参数 `stateStore: FragmentStateStore?`
- 新增便捷属性 `var stateStore: FragmentStateStore?`

**MarkdownRenderEngine.swift**
- 增加 `stateStore: FragmentStateStore?` 属性
- `render()` 创建 Context 时传入 `stateStore`
- `makeDefault()` 增加 `stateStore:` 参数

**MarkdownContainerView.swift**
- 创建并持有 `FragmentStateStore`
- 初始化 engine 时传入 stateStore
- stateStore.onStateChange 触发 `render(streamingBuffer)` 或 `rerenderFragment(id)`
- `clear()` 时调用 `stateStore.gc(existingIds:)` 或 `stateStore.clearState`

---

## 三、Phase 2：View 静态高度计算

### 3.1 新增 FragmentView 协议

**FragmentView.swift**
```swift
public protocol FragmentView: UIView, FragmentConfigurable {
    associatedtype Content
    static func calculateHeight(content: Content, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat
}
```

### 3.2 修改 CodeBlockView

- 实现 `FragmentView` 协议
- 实现 `static func calculateHeight(content: CodeBlockContent, maxWidth:, theme:) -> CGFloat`
- 逻辑从 `CodeBlockContent.calculateEstimatedHeight` 迁移

### 3.3 修改 DefaultCodeBlockRenderer

- 调用 `CodeBlockView.calculateHeight(content:maxWidth:theme:)` 替代 `content.calculateEstimatedHeight`
- Content 创建时需包含状态字段（Phase 3）

### 3.4 修改 CodeBlockContent

- 保持 `calculateEstimatedHeight` 暂时用于兼容，或改为调用 View 的静态方法（需类型信息，可用默认 CodeBlockView）

---

## 四、Phase 3：Content 增加状态字段

### 4.1 修改 CodeBlockContent

```swift
public struct CodeBlockContent {
    public let code: String
    public let language: String
    public let isCopied: Bool   // 从 StateStore 读取
    
    public init(code: String, language: String, isCopied: Bool = false)
}
```

### 4.2 修改 DefaultCodeBlockRenderer

- 获取 fragmentId
- `let interactionState = context.stateStore?.getState(CodeBlockInteractionState.self, for: fragmentId) ?? .defaultState`
- `let content = CodeBlockContent(code:, language:, isCopied: interactionState.isCopied)`
- 高度计算使用 `CodeBlockView.calculateHeight(content:maxWidth:theme:)`

---

## 五、Phase 4：View 去状态化

### 4.1 修改 CodeBlockView

- 移除 `currentCode`、`currentLanguage` 的持久化（仅用于 layout 时的临时计算可保留，但 configure 时从 content 读取）
- `configure(content:theme:)` 仅根据 content 渲染，不维护「复制成功」的 UI 状态
- 复制成功的展示：由 content.isCopied 决定，View 根据其显示「已复制」样式
- 复制操作：改为通过 `onEvent?(CopyEvent(fragmentId:, copiedText:))` 上报

### 4.2 复制流程

1. 用户点击复制
2. View 调用 `onEvent?(CopyEvent(fragmentId: fragmentId, copiedText: code))`
3. ContainerView.handleEvent 更新 StateStore
4. onStateChange 触发 render
5. Renderer 组装 Content(isCopied: true)
6. View.configure 显示「已复制」样式
7. 2 秒后 Handler 再次 updateState(isCopied: false)，同理触发 render，恢复原样式

---

## 六、Phase 5：FragmentEvent 与 handleEvent

### 6.1 新增 FragmentEvent.swift

```swift
public protocol FragmentEvent {
    var fragmentId: String { get }
}

public struct CopyEvent: FragmentEvent {
    public let fragmentId: String
    public let copiedText: String
}
```

### 6.2 修改 FragmentConfigurable

- 增加可选 `var onEvent: ((FragmentEvent) -> Void)?`，或单独定义 `FragmentEventReporting` 协议
- 或：由 ContainerView 在 configure 时注入 closure

### 6.3 修改 CodeBlockView

- 增加 `var fragmentId: String = ""`（configure 时设置）
- 增加 `var onEvent: ((FragmentEvent) -> Void)?`
- copyCode() 中调用 `onEvent?(CopyEvent(fragmentId: fragmentId, copiedText: currentCode))`，不再本地做 2 秒还原

### 6.4 修改 MarkdownContainerView

- 实现 `handleEvent(_ event: FragmentEvent)`
- 处理 CopyEvent：更新 CodeBlockInteractionState，2 秒后重置
- 在 `configureFragmentView` 时为 View 设置 `onEvent` 闭包，闭包内调用 `handleEvent`
- 将 `onEvent` 与 `stateStore`、`currentMarkdown` 等连接

### 6.5 修改 ViewFragment

- configure 闭包需要能够注入 onEvent，View 需要持有 fragmentId
- FragmentConfigurable 的 configure 签名为 `(content, theme)`，可扩展为 `(content, theme, fragmentId?, onEvent?)` 或通过 Content 携带 fragmentId
- CodeBlockContent 可增加 fragmentId 字段，Renderer 创建时填入
- 这样 configure(view, content, theme) 时，content 已有 fragmentId
- onEvent 由 ContainerView 在 configureFragmentView 时设置，需要 View 有 onEvent 属性。FragmentConfigurable 不包含 onEvent，我们通过可选协议或类型转换设置

---

## 七、实施顺序与依赖

| 步骤 | 依赖 | 产出 |
|------|------|------|
| 1 | 无 | FragmentState, FragmentStateStore, CodeBlockInteractionState |
| 2 | 1 | ContextKeys.StateStoreKey, RenderContext.stateStore, Engine.stateStore |
| 3 | 2 | MarkdownContainerView 创建 stateStore、注入 engine、onStateChange→render |
| 4 | 无 | FragmentView 协议, CodeBlockView.calculateHeight |
| 5 | 4 | DefaultCodeBlockRenderer 使用 CodeBlockView.calculateHeight |
| 6 | 1,2 | CodeBlockContent 增加 isCopied, Renderer 从 stateStore 组装 |
| 7 | 6 | CodeBlockView configure 根据 content.isCopied 渲染 |
| 8 | 无 | FragmentEvent, CopyEvent |
| 9 | 8, 3 | handleEvent 实现，View.onEvent 注入 |

---

## 八、项目约定

- **无需后向兼容**：本项目为全新项目，可做破坏性更新，技术方案不考虑兼容既有 API。
- 详见 `.cursor/rules/design-principles.mdc`。

---

## 九、实施完成清单（已实现）

- [x] Phase 1: FragmentStateStore、FragmentState、CodeBlockInteractionState、StateStoreKey、RenderContext/Engine 注入、ContainerView 创建并监听 onStateChange
- [x] Phase 2: FragmentView 协议、CodeBlockView.calculateHeight、Renderer 调用静态方法
- [x] Phase 3: CodeBlockContent 增加 fragmentId、isCopied，Renderer 从 stateStore 组装
- [x] Phase 4: CodeBlockView configure 根据 content.isCopied 渲染，updateCopyButtonAppearance
- [x] Phase 5: FragmentEvent、CopyEvent、FragmentEventReporting、handleEvent、2 秒后重置（使用 theme.copySuccessDuration）

### 新增文件

- `State/FragmentState.swift`
- `State/FragmentStateStore.swift`
- `State/States/CodeBlockInteractionState.swift`
- `State/FragmentEvent.swift`
- `Protocols/FragmentView.swift`

### 修改文件

- `Core/ContextKeys.swift`：StateStoreKey
- `Core/RenderContext.swift`：stateStore 参数与属性
- `Engine/MarkdownRenderEngine.swift`：stateStore 注入
- `Engine/Defaults/DefaultRenderers.swift`：CodeBlockContent 构造、stateStore 读取、CodeBlockView.calculateHeight
- `Public/MarkdownContainerView.swift`：stateStore、handleStateChange、handleEvent、configureFragmentView 注入 onEvent
- `Views/CodeBlockView.swift`：FragmentView、FragmentEventReporting、configure 使用 content.isCopied、copyCode 上报事件
