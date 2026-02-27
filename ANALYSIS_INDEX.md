# XHSMarkdownKit 分析文档索引

> 本索引汇总工程中的各类分析报告，便于查阅和追溯

---

## 文档列表

| 文档 | 说明 | 状态 |
|------|------|------|
| [HARDCODE_ANALYSIS.md](./HARDCODE_ANALYSIS.md) | 硬编码分析：可配置到 theme、可用 enum 替代、可常量化 | ✅ 已实施修复 |
| [SPECIAL_LOGIC_ANALYSIS.md](./SPECIAL_LOGIC_ANALYSIS.md) | 特殊逻辑分析：类型多态、default 分支、业务特化等 | 📋 待实施 |
| [FRAGMENT_STATE_DESIGN.md](./Sources/XHSMarkdownKit/FRAGMENT_STATE_DESIGN.md) | Fragment 外部状态管理技术方案 | 📐 设计参考 |

---

## 一、硬编码分析（HARDCODE_ANALYSIS.md）

### 概览
- **可配置到 theme**：18 项
- **可用 enum 替代**：12 项
- **可常量化**：26 项

### 已完成的修复
- 新增 `ReuseIdentifier`、`PathPrefix`、`NodeTypeName`、`PathComponent`、`RendererCategory`、`InlineDelimiter`、`CodeFence`
- 新增 `AnimationConstants`、`AlphaFadeConstants`、`CodeBlockConstants`、`TextViewConstants`、`PathConstants`、`TableLayoutConstants`、`SpeedStrategyConstants`
- 扩展 `MarkdownTheme`：CodeBlock copyButton 文案图标、contentPadding、letterSpacing、springSlideOffsetRatio、expandInitialScale
- 各 Renderer、ContainerView、CodeBlockView、MarkdownImageView 等已接入 enum 和 theme

---

## 二、特殊逻辑分析（SPECIAL_LOGIC_ANALYSIS.md）

### 概览
- **类型多态缺失**：8 处（as?/is 类型判断）
- **默认分支/兜底逻辑**：9 处
- **模式/场景分支**：6 处
- **业务特化逻辑**：7 处

### 改进优先级
| 优先级 | 问题 | 方案 |
|--------|------|------|
| 高 | Fragment→View 类型判断分散 | 引入 FragmentViewFactory 或 presentationStyle |
| 高 | isViewTypeMatching default: true | 移除宽松 default，强制显式注册 |
| 中 | ViewFragment 恒认为有更新 | 为 Content 实现 Equatable |
| 中 | MarkdownNodeType 未知类型当作 document | 增加 .unknown 并走 FallbackRenderer |
| 低 | 动画 isEnabled 分散判断 | 用 AnimationExecutor 或 Null Object 统一 |

---

## 三、Fragment 状态设计（FRAGMENT_STATE_DESIGN.md）

### 核心方案
- **FragmentStateStore**：统一管理外部状态
- **View 无状态化**：只根据 Content 渲染
- **高度计算**：View 层静态方法 `calculateHeight(content:maxWidth:theme:)`
- **事件上报**：FragmentEvent → ContainerView → StateStore

---

*更新时间：2026-02-27*
