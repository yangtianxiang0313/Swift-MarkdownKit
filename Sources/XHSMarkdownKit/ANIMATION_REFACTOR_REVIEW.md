# 动画与高度改造方案 — 回顾与待确认点

> 对 FRAGMENT_HEIGHT_REFACTOR、ANIMATION_IMPLEMENTATION_SPEC、ANIMATION_SYSTEM_REDESIGN 的全面回顾

---

## 一、待确认 / 需决策

### 1. render/apply 与 driver 的统一路径

**现状**：`render()` → `apply()` → `applyFragments()` 为独立路径，不走 driver；`appendText()` → `applyDiff()` → `handleInsert/Update/Delete` 走现有 AnimationController。

**设计目标**：统一由 driver 驱动，无 `animated` 分支。

**待确认**：`apply()` 是否改为复用 `applyDiff` 逻辑？

建议：`apply(result)` 改为：

```text
let oldFragments = renderResult?.fragments ?? []
renderResult = result
calculateFrames(for: result.fragments)
driver.applyDiff(StreamingFragmentDiffer.diff(old: oldFragments, new: result.fragments), fragments: result.fragments, frames: fragmentFrames)
```

这样 `render()` 和 `appendText()` 都走同一套 driver.applyDiff，`applyFragments` 可移除。请确认是否按此统一。

---

### 2. FragmentViewFactory.estimatedHeight 的 theme 参数

**现状**：`estimatedHeight(atDisplayedLength:maxWidth:)` 无 theme 参数。

**问题**：View 静态方法 `estimatedHeight(attributedString, displayedLength, maxWidth, theme)` 需要 theme（字体、行高等）才能正确算高。

**建议**：增加 theme 参数：

```swift
func estimatedHeight(atDisplayedLength displayedLength: Int, maxWidth: CGFloat, theme: MarkdownTheme) -> CGFloat
```

Container 调用时传入 `engine.theme`。请确认。

---

### 3. ViewFragment 的 estimatedHeight 分发逻辑 — 已确定：依赖倒置

**决策**：采用 **FragmentHeightProvider 协议**（创建时注入），符合依赖倒置与「少用闭包、多用协议」原则。

- ViewFragment、TextFragment 在创建时可选传入 `heightProvider: FragmentHeightProvider?`
- 框架只做调用，**零内部 switch**
- 用户新增 ViewFragment 类型时，定义自己的 struct 遵循 `FragmentHeightProvider` 并传入，无需改框架任何代码
- 该原则已写入 rule：用户扩展时不应修改框架内部代码

---

### 4. 自定义 View 在 animationProgress 模式下的高度 — 已确定

**方案**：用户在创建 ViewFragment 时传入自定义的 `FragmentHeightProvider` 实现即可。provider 内可调用自定义 View 的静态 `estimatedHeight`，框架不做任何分支，依赖倒置。

---

### 5. contentHeightNeedsUpdateFor 的调用方与条件

**现状**：仅 StreamAnimator 在 tick 中、reveal 后调用；InstantAnimationDriver 不调用。

**待确认**：StreamAnimator 需访问 `fragmentHeightMode` 才决定是否调用。StreamAnimator 通过 config 注入，需保证能拿到 `config.fragmentHeightMode`。实现上是否由 Container 创建 StreamAnimator 时传入包含 `fragmentHeightMode` 的 config？请确认配置传递链。

---

## 二、潜在缺口与建议补充

### 2.1 SimpleStreamableContent 的 totalLength

**问题**：extension 中有 `displayedLength = totalLength`，但 `totalLength` 需 conforming 类型实现。

**建议**：在 5.7 中注明：遵循 SimpleStreamableContent 的类型必须实现 `totalLength`，通常为 `0`（无内容）或固定值。示例中给出 `var totalLength: Int { 0 }`。

---

### 2.2 animationProgress 时 frame 的 y 计算

**问题**：当前 fragment 高度变化时，其 frame.origin.y 为前面所有 fragment 高度之和；后续 fragment 未创建，无需更新。

**建议**：在 FRAGMENT_HEIGHT_REFACTOR 的 2.4 明确：  
只更新当前 fragment 的 frame.size.height，frame.origin.y 保持不变；contentHeight = 前面累加 + 当前 fragment 新高度。

---

### 2.3 handleUpdate 时的 frame 变化

**现状**：ANIMATION_SYSTEM_REDESIGN 4.9 约定「流式场景下已加入的 fragment 的 frame 不变」。

**冲突**：在 animationProgress 模式下，当前 fragment 的 height 会随 displayedLength 变化。

**建议**：将「frame 不变」限定为「已完成动画的 fragment」；正在播放的 fragment 在 animationProgress 下允许 height 变化。在文档中单独说明这一例外。

---

### 2.4 endStreaming 的行为

**现状**：endStreaming 会调用 applyDiff 做最终渲染，此时可能仍有进行中的动画。

**建议**：明确 endStreaming 时是否等待动画完成，或直接 applyDiff 覆盖。当前实现为直接 applyDiff，建议保持不变并在文档中说明。

---

## 三、文档间一致性检查

| 项目 | 高度方案 | 动画规格 | 设计文档 | 一致性 |
|------|----------|----------|----------|--------|
| contentHeight 计算 | 按 heightMode 分支，含 theme | 引用高度方案 | 4.9 为旧逻辑 | 需同步 4.9 |
| delegate 方法 | contentHeightNeedsUpdateFor | 已包含 | 未提及 | 可接受 |
| View 静态方法 | 需 theme；FragmentHeightProvider 依赖倒置 | 引用 | - | 已统一 |
| render/apply 路径 | - | 已补充 apply 统一 | 4.4 提 applyDiff | 已统一 |

---

## 四、已完成的文档更新

1. **ANIMATION_IMPLEMENTATION_SPEC**：已补充 apply 统一任务。
2. **FRAGMENT_HEIGHT_REFACTOR**：已增加 theme 参数；已改为 FragmentHeightProvider 协议依赖倒置，无框架内部 switch。
3. **design-principles.mdc**：已增加「依赖倒置」设计原则。
4. **ANIMATION_REFACTOR_REVIEW**：已更新决策与一致性。

---

## 五、实施顺序（建议）

1. **FRAGMENT_HEIGHT_REFACTOR** Phase 1–3（含 theme 参数、ViewFragment 分发逻辑）
2. **ANIMATION_IMPLEMENTATION_SPEC** Phase 1–4
3. **render/apply 统一**：在 Phase 3 Container 集成时一并完成
4. **CUSTOM_VIEW_ANIMATION** 文档

---

*版本：2026-02-27*
