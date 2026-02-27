# Fragment 外部状态管理设计方案

> 从第一性原理出发，识别核心问题，给出最小必要设计。

---

## 一、第一性原理：核心问题

### 1.1 问题的本质

```
最终渲染结果 = f(原始数据, 外部状态)
```

- **原始数据**：来自 Markdown 文本，由 `render()` 时的 AST 决定，每次 render 都可重新推导
- **外部状态**：来自用户行为、时间、异步回调等，**不随 render 自动推导**，必须独立存储

当用户点击「折叠」、图片加载完成、复制成功提示 2 秒后消失时，这些状态需要在**多次 render 之间保持**。

### 1.2 五个核心问题

| # | 问题 | 本质 | 不解决的后果 |
|---|------|------|--------------|
| **P1** | 状态跨 render 丢失 | 每次 `render()` 重建 Fragment/Content，外部状态无处存放 | 折叠、加载中、复制提示等状态在流式更新或重渲时消失 |
| **P2** | View 复用污染 | View 被复用池回收后用于其他 Fragment，若 View 持有状态会显示错误内容 | 复用的 CodeBlockView 显示上一个代码块的折叠状态 |
| **P3** | 高度计算分散 | 高度依赖 content + 外部状态（如 collapsed），计算散落在 View/Content/Renderer | 替换 View 时高度逻辑丢失；多处计算不一致 |
| **P4** | 更新路径不统一 | 流式追加、用户点击、异步回调走不同路径更新 UI | 难以协调；竞态；部分场景状态不同步 |
| **P5** | 事件归属模糊 | 用户点击「折叠」时，谁负责更新状态？View 自己改会变成有状态 | View 有状态 → 违反 P2；需要明确「谁改状态」 |

### 1.3 第一性约束（不可违反）

1. **外部状态必须独立于 render 周期存在** → 需要专门的存储
2. **View 必须无状态** → 复用安全，否则 P2 无解
3. **Content 必须是完整渲染输入** → `View.configure(content)` 为纯函数，content 已含所有状态
4. **所有状态变更必须走同一路径** → 更新存储 → 触发渲染 → 组装 Content → 配置 View
5. **View 不写状态，只读并上报事件** → 事件 → Handler → 更新存储 → 回到路径 4

---

## 二、最小必要设计

### 2.1 架构原则

- **单一数据源**：外部状态只在 `FragmentStateStore` 中
- **单向数据流**：StateStore → Renderer(组装 Content) → Diff → View.configure
- **View 为纯渲染**：`configure(content)` 无副作用，不持有状态

### 2.2 核心组件与职责

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        最小必要架构                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  触发源（用户/时间/异步）                                                │
│       │                                                                  │
│       ▼                                                                  │
│  ┌──────────────────┐     onStateChange                                 │
│  │ FragmentStateStore│ ─────────────────────────┐                       │
│  │ [fragmentId: S]   │                          │                       │
│  └──────────────────┘                          │                       │
│       ▲                                        │                       │
│       │ updateState()                          ▼                       │
│       │                          ┌──────────────────────┐               │
│  handleEvent()                    │ render()             │               │
│       │                          │  · stateStore.get()  │               │
│       │                          │  · Content = raw+state │             │
│       │                          │  · height = View.calc() │             │
│       │                          └──────────┬───────────┘               │
│       │                                     │                           │
│       │                                     ▼                           │
│       │                          ┌──────────────────────┐               │
│       └──────────────────────────│ View.configure(content)│              │
│                                  │ 无状态，纯渲染         │               │
│                                  └──────────────────────┘               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 数据流（唯一路径）

```
状态变更 → StateStore.updateState()
              │
              │ onStateChange 回调
              ▼
       containerView.render()  // 或 rerenderFragment(id)
              │
              ▼
       Renderer.render(context)
              │
              │ 1. context.stateStore.getState(fragmentId)
              │ 2. Content = 原始数据 + 状态
              │ 3. height = ViewType.calculateHeight(content, ...)
              │ 4. ViewFragment(content, estimatedSize)
              ▼
       Diff → View.configure(content)
```

---

## 三、核心类型定义

### 3.1 FragmentStateStore

**职责**：唯一持有跨 render 的外部状态。

```swift
public final class FragmentStateStore {
    private var states: [String: [String: Any]] = [:]  // [fragmentId: [stateType: state]]
    var onStateChange: ((String) -> Void)?
    
    func getState<S: FragmentState>(_ type: S.Type, for fragmentId: String) -> S
    func updateState<S: FragmentState>(_ state: S, for fragmentId: String, triggerRender: Bool = true)
    func clearState(for fragmentId: String)
    func gc(existingIds: Set<String>)
}
```

### 3.2 FragmentState 协议

**职责**：类型化的状态，每种状态有标识和默认值。

```swift
public protocol FragmentState {
    static var stateType: String { get }
    static var defaultState: Self { get }
}
```

**示例**：`CollapsedState`、`LoadingState`、`InteractionState`（复制提示等）

### 3.3 Content = 原始数据 + 外部状态

**职责**：View 的完整输入，无计算逻辑。

```swift
// 示例：代码块 Content
struct CodeBlockContent {
    let code: String
    let language: String
    let isCollapsed: Bool    // 从 StateStore 读取后填入
    let isCopied: Bool       // 从 StateStore 读取后填入
}
```

### 3.4 View 静态高度计算

**职责**：高度依赖 content（已含状态），计算逻辑随 View 实现走。

```swift
protocol FragmentView: UIView {
    associatedtype Content
    static func calculateHeight(content: Content, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat
}
```

**原因**：用户可替换 View 实现，高度逻辑应一起替换；Content 保持纯数据。

### 3.5 FragmentEvent 与 handleEvent

**职责**：View 上报事件，ContainerView 负责更新 StateStore。

```swift
protocol FragmentEvent { var fragmentId: String { get } }

// ContainerView
func handleEvent(_ event: FragmentEvent) {
    switch event {
    case let e as CollapseToggleEvent:
        var s = stateStore.getState(CollapsedState.self, for: e.fragmentId)
        s.isCollapsed.toggle()
        stateStore.updateState(s, for: e.fragmentId)
    // ...
    }
}
```

---

## 四、问题与方案对照

| 核心问题 | 方案 |
|----------|------|
| P1 状态跨 render 丢失 | `FragmentStateStore` 独立于 render 存在，`render()` 时从中读取 |
| P2 View 复用污染 | View 无状态，`configure(content)` 纯渲染，不持有 `isCollapsed` 等 |
| P3 高度计算分散 | `ViewType.calculateHeight(content:...)` 唯一来源，Renderer 调用 |
| P4 更新路径不统一 | 所有变更：`updateState` → `onStateChange` → `render()` → Diff → `configure` |
| P5 事件归属模糊 | View 通过 `onEvent?(CollapseToggleEvent)` 上报，Handler 更新 Store |

---

## 五、与现有设计的衔接

### 5.1 保持不变的部分

- **Fragment**：仍是 Renderer 输出、Diff 输入、布局载体
- **RenderContext**：携带 theme、maxWidth、path 等；**新增** `stateStore` 引用
- **Diff 机制**：流式 diff 逻辑不变
- **View 复用池**：复用策略不变，因 View 无状态而更安全

### 5.2 需要新增的部分

| 组件 | 说明 |
|------|------|
| `FragmentStateStore` | 持有外部状态，注入 RenderContext |
| `FragmentState` 及各状态类型 | CollapsedState、LoadingState 等 |
| `FragmentEvent` + `handleEvent` | View 事件上报与统一处理 |
| `FragmentView` 协议 | 增加 `calculateHeight` 静态方法 |
| Renderer 更新 | 从 stateStore 读状态组 Content，调用 View 静态方法算高度 |

### 5.3 需要移除/改造的部分

- View 内部状态（如 `isCollapsed`）→ 删除，改为从 Content 读取
- Content 内手写高度计算 → 迁移到 View 的 `calculateHeight`
- `DynamicHeightView` → 已移除，由 `FragmentView` + 静态方法替代

### 5.4 项目约定

- **无需后向兼容**：本项目为全新项目，可做破坏性更新。详见 `.cursor/rules/design-principles.mdc`。

---

## 六、迁移阶段

| 阶段 | 内容 |
|------|------|
| **Phase 1** | 引入 `FragmentStateStore`、`FragmentState`，在 RenderContext 中注入 stateStore |
| **Phase 2** | 定义 `FragmentView`，实现 `calculateHeight`，Renderer 改为调用该方法 |
| **Phase 3** | Content 增加状态字段，Renderer 从 stateStore 组装 Content |
| **Phase 4** | View 去状态化，`configure` 仅依赖 Content |
| **Phase 5** | 建立 `FragmentEvent` + `handleEvent`，View 上报事件、Handler 更新 Store |

---

## 七、附录：与旧文档的对应关系

旧文档中的「〇、数据流全景图」「〇.1 关键问题」「〇.2 统一 Fragment 定义」主要解决**数据流与职责划分**，本方案默认这些已澄清，聚焦**外部状态**本身。

旧文档中的「问题 1～4」「统一更新链路」「View 交互事件」等，在本方案中收敛为上述五个核心问题（P1～P5）及其对应设计。

**核心简化**：本方案不展开实现细节（如 `batchUpdate`、`rerenderFragment`），仅明确问题、原则与最小必要架构，具体 API 可在实现时细化。
