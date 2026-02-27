# XHSMarkdownKit 硬编码分析报告

> 排除 MarkdownTheme 相关文件，对工程中所有硬编码进行分类整理

---

## 概览

| 分类 | 数量 | 说明 |
|------|------|------|
| 可配置到 theme 的 | 18 | 颜色、尺寸、文案、图标等视觉相关，建议迁移到 `MarkdownTheme` |
| 可用 enum 替代的 | 12 | 字符串字面量作为标识符，建议用 `enum` 增强类型安全 |
| 可常量化（提取为常量）的 | 26 | Magic number、固定字符串，建议提取为 `static let` 常量 |

---

## 一、可配置到 theme 的

> 建议迁移到 `MarkdownTheme`，使宿主 App 可自定义

### 1.1 CodeBlockView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L23 | `"复制"` | 复制按钮文案 | 在 `MarkdownTheme.CodeBlockHeaderStyle.ButtonStyle` 中新增 `copyTitle: String` |
| L24 | `"doc.on.doc"` | 复制图标 SF Symbol | 在 ButtonStyle 中新增 `copyIconName: String` |
| L24 | `pointSize: 11` | 图标尺寸 | 在 ButtonStyle 中新增 `iconPointSize: CGFloat` |
| L254 | `"已复制"` | 复制成功反馈文案 | 在 ButtonStyle 中新增 `copiedTitle: String` |
| L255 | `"checkmark"` | 复制成功图标 | 在 ButtonStyle 中新增 `copiedIconName: String` |
| L256-257 | `.systemGreen` | 复制成功后的文本颜色 | 在 ButtonStyle 中新增 `copiedTextColor: UIColor` |
| L185-186 | `+ 2` | 代码区域计算时的余量 | 在 `CodeBlockStyle` 中新增 `contentPadding: CGFloat`（或扩展 padding） |
| L287 | `max(b - percentage, 0)` 中的 `0` | 颜色变暗的最小亮度 | 在 `CodeBlockHeaderStyle` 的 `darker(by:)` 逻辑中，可配置 `minBrightness` |

### 1.2 AlphaFadeInDisplayStrategy.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L30 | `1.0` | 判断动画完成的余量时间（秒） | 在 `MarkdownTheme.AnimationStyle` 或策略初始化参数中配置 `completionTolerance` |
| L136 | `UIColor.clear` | 未激活字符的占位颜色 | 可配置为 theme 的 `invisibleTextColor`（或保持 clear 作为语义常量） |

### 1.3 MarkdownImageView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L73 | `height: 200` | 占位图默认高度 | **直接改为** `theme.image.placeholderHeight`（MarkdownTheme 中已定义，DefaultImageRenderer 已使用） |

### 1.4 EnterAnimationExecutor.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L127 | `slideUpOffset / 2` | 弹性动画的偏移量系数 | 在 `EnterAnimationStyle` 中新增 `springSlideOffsetRatio: CGFloat` |
| L181 | `scaleX: 0.95, y: 0` | Expand 动画的初始缩放 | 在 `EnterAnimationStyle` 中新增 `expandInitialScale: CGFloat` |

### 1.5 InlineRenderer.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L119 | `.kern: 0` | 行内代码字间距 | 使用 `theme.code.letterSpacing`（若 theme 已支持）或新增该字段 |
| L171 | `"\n"` | LineBreak 换行符 | 规范行为，可保持；若需国际化可配置 |
| L173 | `" "` | SoftBreak 空格 | 同上，一般无需配置 |

### 1.6 AnimationConfig.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L35-36 | `duration: 0.2` | 默认动画时长 | 可考虑从 theme 读取 `animation.enter.fadeInDuration` |
| L41-42 | `duration: 0.15` | 快速淡入时长 | 同上 |
| L48-49 | `duration: 0.25` | slideUp/expand 时长 | 同上 |
| L124-126 | `speedMultiplier: 1.0/1.5/0.8/2.0` | 内容动画倍率 | 可在 theme 的 streaming 配置中提供预设 |

---

## 二、可用 enum 替代的

> 建议用 `enum` 替代字符串字面量，提升类型安全和可维护性

### 2.1 DefaultRenderers.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L26 | `"doc"` | Document 路径前缀 | 定义 `enum PathPrefix { case doc; var rawValue: String }` |
| L51 | `"para"` | 段落节点类型名 | 定义 `enum NodeTypeName { case para; var rawValue: String }` |
| L92 | `"h\(level)"` | 标题节点类型名 | 同上，`case heading(Int)` |
| L127 | `"code"` | 代码块节点类型名 | 同上 |
| L129 | `"CodeBlockView"` | 复用标识符 | 定义 `enum ReuseIdentifier { case codeBlockView; var rawValue: String }` |
| L205 | `"bq"` | 引用块路径前缀 | 同 PathPrefix |
| L230, L258 | `"li_\(index)"` | 列表项路径组件 | 使用 `PathComponent.listItem(index)` |
| L291 | `"c\(childIndex)"` | 子节点路径组件 | 使用 `PathComponent.child(index)` |
| L400-402 | `"table"`, `"MarkdownTableView"` | 表格相关 | 同 NodeTypeName、ReuseIdentifier |
| L511-513 | `"hr"`, `"ThematicBreakView"` | 分割线相关 | 同上 |
| L550-552 | `"img"`, `"MarkdownImageView"` | 图片相关 | 同上 |

### 2.2 MarkdownContainerView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L279 | `"text"` | 文本 Fragment 的默认复用 ID | 使用 `ReuseIdentifier.textView.rawValue` |
| L335 | `"text"` | 同上 | 同上 |
| L442 | `"blockQuoteText"` | 引用块文本复用 ID | 使用 `ReuseIdentifier.blockQuoteText.rawValue` |
| L497 | `"text"` | 复用池 key | 同上 |
| L541-547 | `"CodeBlockView"`, `"MarkdownTableView"` 等 | View 类型匹配的 switch | 使用 `ReuseIdentifier` enum 的 switch |

### 2.3 RendererRegistry.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L135 | `"heading"` | 通配渲染器类别 | 定义 `enum RendererCategory { case heading; var rawValue: String }` |
| L149 | `"list"` | 同上 | 同上 |
| L153 | `"taskListItem"` | 同上 | 同上 |

### 2.4 MarkdownPreprocessor.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L29 | `["***", "**", "~~", "__", "_", "*", "\`"]` | 行内定界符 | 定义 `enum InlineDelimiter: String, CaseIterable` |
| L51, 53 | `"```"`, `"~~~"` | 围栏代码块标记 | 定义 `enum CodeFence: String { case backtick = "```"; case tilde = "~~~" }` |

---

## 三、可常量化（提取为常量）的

> 建议提取为 `static let` 或模块级常量，避免 Magic Number/String

### 3.1 BlockQuoteTextView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L24 | `lineFragmentPadding = 0` | 文本边距 | 提取为 `TextViewConstants.lineFragmentPadding` |
| L94 | `lineWidth / 2` | 竖线圆角（半宽成圆） | 语义明确，可提取 `cornerRadius = lineWidth / 2` 为计算属性或常量说明 |

### 3.2 MarkdownContainerView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L238, L286 | `view.alpha = 0` | 初始隐藏 | 提取 `AnimationConstants.initialAlpha` |
| L324, L521 | `view.alpha = 1` | 显示完成 | 提取 `AnimationConstants.visibleAlpha` |
| L254 | `length: 0` | ContentUpdateResult 初始值 | 语义常量，可提取 `ContentUpdateResult.zero` |

### 3.3 MarkdownTableView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L62 | `+ 1` | 行数（含表头） | 提取 `TableLayoutConstants.headerRowOffset` |
| L148 | `lineFragmentPadding = 0` | 单元格文本边距 | 同 BlockQuoteTextView |
| L210 | `max(0, rowHeights.count - 1)` | 边框数 | 提取为 `borderCount(rowCount:)` 辅助方法 |

### 3.4 CodeBlockView.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L42 | `numberOfLines = 0` | 多行显示 | 提取 `CodeBlockConstants.unlimitedLines` |
| L185-186 | `ceil(...) + 2` | 代码尺寸余量 | 提取 `CodeBlockConstants.sizePadding: CGFloat = 2` |

### 3.5 AlphaFadeInDisplayStrategy.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L26 | `min(1, max(0, ...))` | Alpha 钳制范围 | 提取 `AlphaFadeConstants.minAlpha = 0`, `maxAlpha = 1` |
| L45 | `fadeDuration: CFTimeInterval = 0.5` | 默认渐入时长 | 提取 `AlphaFadeConstants.defaultFadeDuration` |
| L112 | `alpha < 1.0` | 完成阈值 | 提取 `AlphaFadeConstants.completionThreshold` |

### 3.6 EnterAnimationExecutor.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L63-65, L75-76 等 | `delay: 0` | 动画延迟 | 提取 `AnimationConstants.zeroDelay` |
| L71 | `translationX: 0` | 水平位移 | 可提取 `AnimationConstants.noTranslation` |

### 3.7 StreamingSpeedStrategy.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L81 | `baseCharsPerFrame + 1` | 轻微积压增量 | 提取 `SpeedStrategyConstants.lightBacklogIncrement` |
| L85-91 | `* 2`, `* 3`, `* 4` | 倍速系数 | 已在 theme 的 `multipliers` 中，此处为默认策略逻辑，可保持 |
| L111 | `minCharsPerFrame: Int = 1` | 线性策略默认 | 提取 `LinearSpeedStrategy.defaultMinChars` |
| L112 | `maxCharsPerFrame: Int = 8` | 同上 | 提取 `defaultMaxChars` |
| L113 | `maxThreshold: Int = 200` | 同上 | 提取 `defaultMaxThreshold` |
| L146-148 | `base: 1.02`, `scaleFactor: 1.0`, `maxCharsPerFrame: 20` | 指数策略默认 | 分别提取常量 |
| L159 | `/ 100.0` | 指数缩放除数 | 提取 `ExponentialSpeedStrategy.scaleDivisor` |
| L190-193 | `historyWindowSize: 10` 等 | 自适应策略默认 | 提取为各类型的默认参数 |
| L232 | `min(3, ...)` | 趋势计算窗口 | 提取 `AdaptiveSpeedStrategy.trendWindowSize` |
| L255 | `fixedCharsPerFrame: Int = 2` | 固定策略默认 | 提取 `FixedSpeedStrategy.defaultCharsPerFrame` |
| L274 | `Int.max` | 即时显示策略 | 提取 `InstantSpeedStrategy.unlimitedChars` |

### 3.8 DocumentCache.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L20 | `countLimit: Int = 100` | 缓存数量上限 | 提取 `DocumentCache.defaultCountLimit` |

### 3.9 RenderContext.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L96 | `"\(pathPrefix)_\(component)"` | 路径拼接分隔符 | 提取 `PathConstants.separator = "_"` |

### 3.10 XHSMarkdownKit.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L23-25 | `major = 2`, `minor = 0`, `patch = 0` | 版本号 | 已是公开 API，保持即可；若需可配置则用 build 脚本注入 |

### 3.11 InlineRenderer.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L42 | `lineSpacing = 0` | 段落行间距 | 可提取 `ParagraphStyleDefaults.zeroLineSpacing`（或保持，语义清晰） |

### 3.12 MarkdownPreprocessor.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L45 | `"\n"` | 行分隔符 | 提取 `MarkdownPreprocessor.lineSeparator` |
| L89 | `"\n\n"` | 段落分隔符 | 提取 `MarkdownPreprocessor.paragraphSeparator` |
| L122 | `count % 2 == 1` | 奇数判断（未闭合） | 提取 `DelimiterLogic.isUnclosed(count:)` 或注释说明 |

### 3.13 BlockSpacingResolving.swift

| 位置 | 当前值 | 说明 | 建议修改方式 |
|------|--------|------|--------------|
| L99 | `* 0.5` | CompactBlockSpacingResolver 间距缩减系数 | 提取 `CompactBlockSpacingResolver.spacingMultiplier: CGFloat = 0.5` |

---

## 四、其他说明

### 4.1 无需处理的硬编码

- **逻辑必需的 0/1**：如 `view.alpha = 0`、`index > 0`、`reduce(0, +)` 等，属于算法/布局逻辑，无需提取。
- **坐标原点**：`x: 0`, `y: 0` 等布局起点。
- **API 要求的参数**：如 `NSRange(location: i, length: 1)` 中的 1。
- **DEBUG 日志**：`#if DEBUG` 内的 print 字符串可保留。

### 4.2 MarkdownTheme 已覆盖的项

以下值已在 `MarkdownTheme` 中定义，若在业务代码中仍被硬编码，应改为从 theme 读取：

- `theme.image.placeholderHeight` → MarkdownImageView L73 应使用此值
- 各种 `lineFragmentPadding = 0` 可考虑是否纳入 theme 的 `TextViewStyle`

### 4.3 建议的常量/枚举定义位置

| 类型 | 建议文件 |
|------|----------|
| `ReuseIdentifier` | `Sources/XHSMarkdownKit/Core/ReuseIdentifier.swift` |
| `PathPrefix` / `NodeTypeName` | `Sources/XHSMarkdownKit/Core/ContextKeys.swift` 或新建 `FragmentIdentifiers.swift` |
| `InlineDelimiter` / `CodeFence` | `Sources/XHSMarkdownKit/Streaming/MarkdownPreprocessor.swift` 内或同目录 |
| `AnimationConstants` | `Sources/XHSMarkdownKit/Animation/AnimationConstants.swift` |
| 各策略的默认参数 | 各 Strategy 文件内的 `extension` 或 `static` |

---

## 五、优先级建议

1. **高优先级**：可配置到 theme 的（影响宿主定制能力）→ CodeBlockView 的「复制」/「已复制」文案与图标
2. **中优先级**：ReuseIdentifier、PathPrefix、NodeTypeName 等 enum 化（减少拼写错误、便于重构）
3. **低优先级**：常量化（提升可读性，对行为无影响）

---

*生成时间：2026-02-27*
