# XHSMarkdownKit Capability Playbook

## 1. 目标

这份文档用于回答两个问题：

1. 框架现在有哪些可扩展能力。
2. Example 工程里每个能力在哪里、怎么操作、看什么结果。

当前推荐标准入口：`MarkdownRuntime`。

## 2. 能力矩阵

| 能力域 | SDK 真源 | 外部扩展点 | Example 入口 |
| --- | --- | --- | --- |
| 节点结构扩展 | `TagSchema / NodeSpec / TreeValidator` | 注册 tag/schema，不改 parser 主干 | `CustomRendererDemo` -> `节点流程` |
| 语义渲染扩展 | `CanonicalRendererRegistry` | 给扩展节点补 block/inline 语义渲染 | `ExampleMarkdownRuntime.makeCanonicalRendererRegistry()` |
| UIKit 渲染扩展 | `RenderModelUIKitAdapter` | 覆写 block mapper / inline renderer | `CustomRendererDemo` -> `渲染定制` |
| 统一事件总线 | `MarkdownEvent` | 通过 `eventHandler` 观察/拦截默认副作用 | `CustomRendererDemo` -> `Runtime` |
| SDK 托管状态 | `MarkdownStateSnapshot / MarkdownStateStore` | 外部不维护增量状态机，只读观察 snapshot | `CustomRendererDemo` -> `Runtime` |
| 延迟副作用 | `EffectRunner` + `NodeBehaviorSchema.effectSpecs` | 声明 action -> 延迟 emitted action | `codeBlock copy -> 5s reset`（Runtime 页） |
| 状态持久化 | `MarkdownStatePersistenceAdapter` | 只实现 load/save | `CustomRendererDemo` -> `状态恢复` |
| 关联数据透传 | `MarkdownDataBindingAdapter` | 组装业务关联字段到 `associatedData` | `CustomRendererDemo` -> `Runtime` / `状态恢复` 事件日志 |
| 动画与流式 | `StreamingSession + SceneDiff` | 配置动画策略，不持有业务状态 | `流式+动画` / `动画参数` |

## 3. 新增节点标准流程

目标链路固定：`TagSchema -> NodeSpec -> Parser -> Canonical -> RenderModel`。

1. 在 `TagSchemaRegistry` 增加声明：`tagName/nodeKind/role/childPolicy/pairingMode`。
2. parser 按注册信息建树；未注册标签 fail-fast 报错 `unknown_node_kind`。
3. canonical 层按需补专用渲染；未补时走 role-based fallback。
4. UIKit 层按需覆写显示（可选）。
5. 节点需要交互状态时，再补 `NodeBehaviorSchema`（结构与行为分离）。

### 3.1 API 优化：统一扩展描述

新增 `NodeExtensionDescriptor` / `NodeExtensionRegistry`：

1. 一个 descriptor 同时承载 `tag(结构)` 与 `behavior(状态/事件)`。
2. 支持 JSON 下发：`JSONModelCodec.decodeNodeExtensionDescriptors`。
3. 一次安装：`registerExtensionDescriptors` / `installStructure` / `installBehavior`。

## 4. 新增行为标准流程

目标链路固定：`NodeBehaviorSchema -> Event -> Reducer -> Snapshot -> Projected RenderModel`。

1. 在 `NodeBehaviorRegistry` 注册 `kind/stateSlots/actionMappings/effectSpecs/stateKeyPolicy`。
2. 交互组件只上报 `action + payload`，统一进入 `MarkdownEvent`。
3. runtime reducer 更新 snapshot（`revision` 单调递增）。
4. `StateProjector` 把 `uiState` 投影回 renderModel，渲染层只消费投影结果。
5. 需要延迟动作时由 `effectSpecs` 声明，不在 UI 组件里写计时器。

## 5. Example 能力地图

### 5.1 预览页（`MarkdownPreviewViewController`）

1. 验证 markdown 输入到 runtime 的主链路。
2. 验证 parser/renderer 报错观测（点击错误提示可复制 payload）。
3. 快速验证新增标签在真实 markdown 文本中的解析表现。

### 5.2 主题页（`ThemeSwitchViewController`）

1. 验证样式系统与 runtime 解耦。
2. 验证同一输入在不同主题下的渲染一致性。

### 5.3 自定义页（`CustomRendererDemoViewController`）

#### `节点流程`

1. 覆盖 block leaf/container 与 inline leaf/container。
2. 覆盖 `selfClosing / paired / both` 三种 HTML 配对模式。
3. 包含 `cite` 与 `think` 示例：`<Cite id="...">...</Cite>`、`<Think id="...">...</Think>`。

#### `渲染定制`

1. 覆写 block mapper（callout/panel/codeBlock）。
2. 覆写 inline renderer（mention/badge/chip/cite）。
3. `cite` 演示为“文本 + 自绘角标附件”；角标可点击并走统一 `activate` 事件。
4. 演示“结构不变、显示可替换”的外部定制边界。

#### `Runtime`

1. 统一事件：`activate/toggle/copy/reset/set` 统一日志结构。
2. 事件决策：`activate` 返回 `.handled` 仅阻断默认副作用。
3. 状态与 effect：`copy` 后自动 `reset`（5 秒）。

#### `状态恢复`

1. `Load Doc A / Load Doc B` 切换文档，验证按 `documentID` 的 snapshot 恢复。
2. `Reload Doc` 验证 runtime 重新输入后状态延续。
3. `Dispatch Activate` 演示外部主动注入事件。
4. 事件日志展示 `associatedData`，包含 `businessContext/destination/businessID/citeID/eventURL`。

### 5.4 流式与动画页

1. `StreamingDemoViewController`：流式追加与中断策略。
2. `AnimationDemoViewController`：动画参数组合、差异编排与可视化验证。

## 6. 外部调用方最小职责

调用方只做两件事：

1. `PersistenceAdapter`：存取 snapshot。
2. `DataBindingAdapter`：给事件补业务关联数据。

调用方不再维护：

1. 状态生命周期。
2. 延迟 effect 定时逻辑。
3. 事件分发主干。

## 7. 关键代码入口

1. `Example/ExampleApp/AppDelegate.swift`
2. `Example/ExampleApp/CustomRendererDemoViewController.swift`
3. `Sources/XHSMarkdownKit/Public/MarkdownRuntime.swift`
4. `Sources/XHSMarkdownKit/Contract/TagSchema.swift`
5. `Sources/XHSMarkdownKit/Contract/NodeBehaviorSchema.swift`

## 8. 回归命令

```bash
xcodebuild -scheme XHSMarkdownKit-Package -destination 'platform=iOS Simulator,name=iPhone 16' test
cd Example && xcodebuild -workspace ExampleApp.xcworkspace -scheme ExampleApp -destination 'generic/platform=iOS Simulator' build
```
