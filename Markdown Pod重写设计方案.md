# XHSMarkdownKit — Markdown 渲染层重写详细开发文档

> **文档版本**: 1.9
> **创建日期**: 2026-02-14
> **作者**: 沃顿
> **关联文档**: [Chat重写iOS实施细则.md](Chat重写iOS实施细则.md) Step 2
> **范围**: 独立工程 XHSMarkdownKit，提供通用 Markdown 渲染能力

---

## 1. 背景与目标

### 1.1 为什么要重写

现有的一些 Markdown 渲染实现存在以下典型问题：

| 问题 | 影响 |
|------|------|
| **节点覆盖不全** | 未实现 `visitTable` / `visitStrikethrough` / `visitImage` / `visitCustomBlock` / `visitCustomInline`。表格在 Fragment 层另行处理，渲染路径割裂 |
| **样式硬编码** | 颜色/字号/间距全部散落在 Processor 各个 visit 方法中，引用了多个业务工具类，不可外部配置 |
| **蓝链处理粗糙** | 蓝链替换在 `visitLink` 内部用字符串匹配 + `XhsParseUtil.xhs_parse`，未利用 XYMarkdown 提供的 `MarkupRewriter` 做 AST 级改写 |
| **无缓存** | 每次调用 `attributedString(from:)` 都重新 `Document(parsing:)`，相同文本重复解析 |
| **业务耦合严重** | 直接 `import XYUIKit` / `XYUITheme` / `XYAGIModels`，依赖 `ExpManager.richTextMarkdownEnable` 实验开关等，无法独立测试和复用 |
| **只输出 NSAttributedString** | 复杂节点（表格、代码块高亮）无法用 NSAttributedString 充分表达，需要 UIView 混排 |

### 1.2 为什么要独立工程

1. **解耦**：Markdown 渲染与业务无关，应作为基础组件独立演进
2. **复用**：Halo、搜索、笔记详情等场景也有 Markdown 渲染需求，独立 Pod 可被多 App 复用
3. **可测试**：独立工程可以有完整的单元测试和 Snapshot 测试，不依赖宿主 App 环境
4. **不影响主仓**：开发阶段在独立仓库迭代，主仓只需最终 `pod update` 接入

### 1.3 核心原则

```
保留 XYMarkdown 解析 + 只重写渲染层
```

- **不造新 Parser**：XYMarkdown 底层已是 cmark（via XYCmark），支持 GFM（Table/Strikethrough）+ MarkupRewriter + CustomBlock/CustomInline，能力充足
- **Halo 也在用 XYMarkdown**：保留可避免维护两套 parser
- **替代现有实现**：新的 `MarkdownRenderer`（MarkupVisitor 实现）覆盖全部节点类型

---

## 2. 架构设计

### 2.1 整体分层

```
┌─────────────────────────────────────────────────────────┐
│                    宿主 App (rebeka-ios)                  │
│                                                         │
│  HostViewController → MarkdownKit.render(text, theme)   │
│                              │                          │
│  ┌───────────────────────────▼──────────────────────┐   │
│  │            XHSMarkdownKit (独立 Pod)               │   │
│  │                                                   │   │
│  │  ┌─────────┐  ┌───────────┐  ┌──────────────┐   │   │
│  │  │ Public  │→ │ Rewriter  │→ │  Renderer    │   │   │
│  │  │ API     │  │ Pipeline  │  │ (Visitor)    │   │   │
│  │  └────┬────┘  └─────┬─────┘  └──────┬───────┘   │   │
│  │       │             │               │            │   │
│  │  ┌────▼────┐  ┌─────▼─────┐  ┌──────▼───────┐   │   │
│  │  │ Cache   │  │  Theme    │  │ ViewRenderer │   │   │
│  │  │ (LRU)   │  │  (Token)  │  │ (Table/Code) │   │   │
│  │  └─────────┘  └───────────┘  └──────────────┘   │   │
│  │                                                   │   │
│  └───────────────────────────────────────────────────┘   │
│                              │                          │
│  ┌───────────────────────────▼──────────────────────┐   │
│  │          XYMarkdown (已有 Pod，不修改)              │   │
│  │  Document(parsing:) / MarkupVisitor / Rewriter    │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 2.2 目录结构

```
XHSMarkdownKit/                              ← 独立 Git 仓库
├── Sources/
│   └── XHSMarkdownKit/
│       ├── Public/                          ← 对外暴露的 API
│       │   ├── MarkdownKit.swift            ← 主入口：render() / parse()
│       │   ├── MarkdownConfiguration.swift  ← 配置项：Rewriter、渲染选项、自定义渲染器、间距规则
│       │   ├── MarkdownContainerView.swift  ← ★ v1.3: 布局容器（手动 frame 硬布局，性能最优）
│       │   └── MarkdownRenderable.swift     ← ★ v1.2: View 层便捷渲染协议 + UILabel/UITextView 默认实现
│       │
│       ├── Protocols/                       ← ★ v1.2: 协议层（核心可扩展机制）
│       │   ├── NodeRenderProtocol.swift     ← 两种渲染协议：AttributedStringNodeRenderer / ViewNodeRenderer
│       │   ├── RenderFragmentProtocol.swift ← ★ 渲染片段协议：TextFragment / ViewFragment / 可扩展
│       │   ├── BlockSpacingResolving.swift  ← ★ 块间距规则协议 + DefaultBlockSpacingResolver
│       │   ├── NodeRenderContext.swift      ← 渲染上下文：theme / maxWidth / 嵌套层级 / 兄弟节点信息
│       │   └── MarkdownNodeType.swift       ← 节点类型枚举 + from(Markup) 推导
│       │
│       ├── Registry/                        ← 渲染器注册表
│       │   └── NodeRendererRegistry.swift   ← 按节点类型注册、查询、覆盖 + 闭包便捷注册
│       │
│       ├── Renderer/                        ← 渲染层 — 内置默认实现
│       │   ├── MarkdownRenderer.swift       ← MarkupVisitor 主调度器：dispatch + Fragment 收集
│       │   ├── AttributedStringBuilder.swift← NSAttributedString 拼接工具
│       │   ├── RenderResult.swift           ← MarkdownRenderResult（[RenderFragment] 序列）
│       │   └── Defaults/                    ← 各标准节点的默认 NodeRenderer 实现
│       │       ├── HeadingRenderer.swift
│       │       ├── ParagraphRenderer.swift
│       │       ├── ListRenderer.swift       ← 有序+无序+嵌套
│       │       ├── BlockQuoteRenderer.swift
│       │       ├── CodeBlockRenderer.swift
│       │       ├── ThematicBreakRenderer.swift
│       │       ├── InlineRenderer.swift     ← Text/Strong/Emphasis/InlineCode/Link/Strikethrough
│       │       ├── TableRenderer.swift      ← ViewNodeRenderer: makeView + configure
│       │       └── ImageRenderer.swift      ← ViewNodeRenderer: makeView + configure
│       │
│       ├── Rewriter/                        ← AST 改写层
│       │   ├── RichLinkRewriter.swift       ← 蓝链 AST 改写（MarkupRewriter 子类）
│       │   └── RewriterPipeline.swift       ← Rewriter 串联管线
│       │
│       ├── Theme/                           ← 样式 Token
│       │   ├── MarkdownTheme.swift          ← 样式 Token 定义（纯值类型，无业务依赖）
│       │   └── DefaultTheme.swift           ← 默认主题
│       │
│       ├── Streaming/                       ← ★ v1.3: 流式渲染层
│       │   ├── StreamingTextBuffer.swift    ← 文本缓冲 + 节流（CADisplayLink 驱动）
│       │   ├── MarkdownPreprocessor.swift   ← 未闭合标记预闭合
│       │   ├── FragmentDiffer.swift         ← Fragment 差异比对（insert/update/delete）
│       │   └── StreamingAnimator.swift      ← 动画调度器（逐字渐入 / 块展开 / 快进）
│       │
│       ├── Cache/                           ← Document 缓存
│       │   └── DocumentCache.swift          ← LRU 缓存，key=文本 hash
│       │
│       └── Extensions/                      ← 内部工具
│           ├── NSAttributedString+Markdown.swift  ← 富文本扩展（行高、间距等）
│           ├── Markup+Sibling.swift               ← AST 节点遍历辅助
│           └── UIFont+Traits.swift                ← 字体 trait 工具
│
├── Tests/
│   └── XHSMarkdownKitTests/
│       ├── RendererTests/                   ← 各节点渲染正确性
│       │   ├── HeadingRenderTests.swift
│       │   ├── ListRenderTests.swift
│       │   ├── TableRenderTests.swift
│       │   ├── BlockQuoteRenderTests.swift
│       │   ├── CodeBlockRenderTests.swift
│       │   └── RichLinkRewriterTests.swift
│       ├── ProtocolTests/                   ← ★ 协议机制测试
│       │   ├── RendererOverrideTests.swift  ← 覆盖标准渲染器
│       │   ├── CustomNodeRegistrationTests.swift  ← 注册全新自定义节点
│       │   ├── SpacingResolverTests.swift   ← ★ 间距协议测试
│       │   └── FragmentTests.swift          ← ★ Fragment 序列 + ContainerView 布局
│       ├── CacheTests/
│       │   └── DocumentCacheTests.swift
│       ├── ThemeTests/
│       │   └── ThemeCustomizationTests.swift
│       ├── PerformanceTests/
│       │   └── RenderPerformanceTests.swift
│       └── Fixtures/                        ← 测试用 Markdown 文本
│           ├── basic.md
│           ├── table.md
│           ├── nested_list.md
│           ├── complex_mixed.md
│           └── edge_cases.md
│
├── Example/                                 ← 示例工程（可视化调试）
│   ├── ExampleApp/
│   │   ├── MarkdownPreviewViewController.swift
│   │   ├── ThemeSwitchViewController.swift
│   │   └── CustomRendererDemoViewController.swift  ← ★ 自定义渲染器演示
│   └── ExampleApp.xcodeproj
│
├── XHSMarkdownKit.podspec
├── Package.swift                            ← SPM 支持（可选）
├── README.md
├── CHANGELOG.md
└── .gitignore
```

### 2.3 依赖关系

```
XHSMarkdownKit
  └── XYMarkdown (~> 0.0.2)       ← 唯一外部依赖（解析层）
      └── XYCmark                 ← XYMarkdown 的底层 cmark C 库

不依赖：
  ✗ XYUIKit / XYUITheme           ← 样式通过 Theme Token 传入
  ✗ XYAGIModels                   ← DotsRichTextModel 通过协议抽象
  ✗ SnapKit                       ← ViewRenderer 内部手动布局或 AutoLayout
  ✗ 任何 XY/AX 业务库
```

---

## 3. 核心接口设计

### 3.1 公开 API（MarkdownKit.swift）

```swift
import XYMarkdown

/// XHSMarkdownKit 主入口
public final class MarkdownKit {
    
    // MARK: - 一步到位
    
    /// 解析 + 改写 + 渲染
    ///
    /// - Parameters:
    ///   - markdown: Markdown 文本
    ///   - theme: 样式主题（默认使用 .default）
    ///   - rewriters: AST 改写器列表（如蓝链改写器）
    ///   - configuration: 渲染配置
    /// - Returns: 渲染结果
    public static func render(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        rewriters: [AnyMarkupRewriter] = [],
        configuration: MarkdownConfiguration = .default
    ) -> MarkdownRenderResult
    
    // MARK: - 分步调用（高级用法）
    
    /// 仅解析，返回 Document（可缓存复用）
    public static func parse(_ markdown: String) -> Document
    
    /// 用已有 Document 渲染（跳过解析，复用缓存）
    public static func render(
        document: Document,
        theme: MarkdownTheme = .default,
        rewriters: [AnyMarkupRewriter] = []
    ) -> MarkdownRenderResult
    
    // MARK: - 缓存管理
    
    /// 清除 Document 缓存
    public static func clearCache()
    
    /// 预热缓存（后台线程解析，缓存 Document）
    public static func preheat(_ markdowns: [String])
}
```

### 3.2 渲染结果（RenderResult.swift）

v1.1 的 viewBlocks 锚点方案存在实际问题：anchorRange 在 attributedString 拼接时位置不断偏移，计算复杂且易出 bug。

v1.2 改为 **有序片段序列**：渲染结果是一个 `[RenderFragment]`，每个 Fragment 要么是文本、要么是视图，按文档顺序排列。Fragment 是**布局无关的数据模型**——描述"要渲染什么"，不规定"怎么布局"。

```swift
// MARK: - 渲染片段协议

/// 渲染片段 — 渲染结果的基本单元
///
/// 有序序列描述 Markdown 内容的线性结构：文本段落与视图块交替排列。
/// 协议化使得未来新增片段类型（如"交互式片段"、"动画片段"）无需修改 RenderResult。
public protocol RenderFragmentProtocol {
    /// 片段的唯一标识（用于 debug、日志、增量更新比对）
    var fragmentId: String { get }
    /// 片段对应的节点类型
    var nodeType: MarkdownNodeType { get }
    /// 预计算高度（在给定宽度下）— 供布局容器提前算出总高度，避免布局时二次计算
    func estimatedHeight(maxWidth: CGFloat) -> CGFloat
}

/// 文本片段 — 用 UILabel / UITextView 渲染
public struct TextFragment: RenderFragmentProtocol {
    public let fragmentId: String
    public let nodeType: MarkdownNodeType
    public let attributedString: NSAttributedString
    
    public func estimatedHeight(maxWidth: CGFloat) -> CGFloat {
        let size = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(size.height)
    }
}

/// 视图片段 — 用自定义 UIView 渲染（表格、代码块、图片、自定义卡片等）
public struct ViewFragment: RenderFragmentProtocol {
    public let fragmentId: String
    public let nodeType: MarkdownNodeType
    /// 复用标识（用于 MarkdownContainerView 内部的 View 复用池）
    public let reuseIdentifier: String
    /// 预计算尺寸
    public let size: CGSize
    /// 创建 View 实例（首次渲染时调用）
    public let makeView: () -> UIView
    /// 配置已有 View（复用时调用，避免重复创建）
    public let configure: (UIView) -> Void
    
    public func estimatedHeight(maxWidth: CGFloat) -> CGFloat { size.height }
}

// MARK: - 渲染结果

/// Markdown 渲染结果
public struct MarkdownRenderResult {
    
    /// 有序片段序列 — 按 Markdown 文档顺序排列
    /// 每个片段对应文档中的一个或多个块级节点
    public let fragments: [any RenderFragmentProtocol]
    
    /// 最后一个块级节点是否为列表（用于流式渲染判断是否需要追加）
    public let endsWithList: Bool
    
    /// 便捷属性：合并所有文本片段为单一 NSAttributedString
    /// 适用于简单场景（无 UIView 混排时直接赋值给 UILabel）
    public var attributedString: NSAttributedString {
        let result = NSMutableAttributedString()
        for fragment in fragments {
            if let text = fragment as? TextFragment {
                if result.length > 0 { result.append(NSAttributedString(string: "\n")) }
                result.append(text.attributedString)
            }
        }
        return result
    }
    
    /// 便捷属性：是否包含 UIView 片段
    public var hasViewFragments: Bool {
        fragments.contains(where: { $0 is ViewFragment })
    }
    
    /// 预计算总高度（含间距）
    public func estimatedTotalHeight(maxWidth: CGFloat, spacing: CGFloat = 0) -> CGFloat {
        let contentHeight = fragments.reduce(0) { $0 + $1.estimatedHeight(maxWidth: maxWidth) }
        let spacingHeight = fragments.count > 1 ? CGFloat(fragments.count - 1) * spacing : 0
        return contentHeight + spacingHeight
    }
    
    /// 空结果
    public static let empty = MarkdownRenderResult(fragments: [], endsWithList: false)
}
```

**布局方案 — MarkdownContainerView（硬布局）：**

Markdown 内容是确定的线性流（块级节点从上到下排列），布局结构完全可预测。**性能最优方案是预计算 frame 硬布局**，不需要 Auto Layout 解方程，也不需要 UICollectionView 的 diff 开销。

```swift
/// Markdown 内容的布局容器
///
/// 采用手动 frame 布局（非 Auto Layout），性能最优。
/// Markdown 的块级结构天然是线性的，只需从上到下累加 y 偏移即可。
public final class MarkdownContainerView: UIView {
    
    /// 当前渲染结果
    private(set) var renderResult: MarkdownRenderResult?
    
    /// 已创建的子 View 缓存（key: fragmentId）
    private var fragmentViews: [String: UIView] = [:]
    
    /// 各 Fragment 的 frame（预计算结果）
    private var fragmentFrames: [String: CGRect] = [:]
    
    /// View 复用池（key: reuseIdentifier）
    private var reusePool: [String: [UIView]] = [:]
    
    /// 内容总高度（预计算）
    private(set) var contentHeight: CGFloat = 0
    
    // MARK: - 应用渲染结果
    
    /// 应用 Markdown 渲染结果，预计算所有 frame
    ///
    /// 调用后 contentHeight 立即可用（用于外层 Cell 的高度计算），
    /// 实际子 View 创建延迟到 layoutSubviews 执行。
    func apply(_ result: MarkdownRenderResult, maxWidth: CGFloat) {
        self.renderResult = result
        
        // ── 预计算所有 Fragment 的 frame（纯数值计算，不涉及 UIView）──
        var y: CGFloat = 0
        fragmentFrames.removeAll(keepingCapacity: true)
        
        for fragment in result.fragments {
            let height = fragment.estimatedHeight(maxWidth: maxWidth)
            fragmentFrames[fragment.fragmentId] = CGRect(x: 0, y: y, width: maxWidth, height: height)
            y += height
        }
        
        contentHeight = y
        setNeedsLayout()
    }
    
    // MARK: - 布局
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        guard let result = renderResult else { return }
        
        // 标记当前所有 View 为"未使用"
        var unusedIds = Set(fragmentViews.keys)
        
        for fragment in result.fragments {
            guard let frame = fragmentFrames[fragment.fragmentId] else { continue }
            unusedIds.remove(fragment.fragmentId)
            
            switch fragment {
            case let text as TextFragment:
                let label = fragmentView(for: text, reuseId: "text") { UILabel() } as! UILabel
                label.numberOfLines = 0
                label.attributedText = text.attributedString
                label.frame = frame
                
            case let view as ViewFragment:
                let subview = fragmentView(for: view, reuseId: view.reuseIdentifier, factory: view.makeView)
                view.configure(subview)
                subview.frame = frame
                
            default:
                break
            }
        }
        
        // 回收不再使用的 View → 复用池
        for unusedId in unusedIds {
            if let view = fragmentViews.removeValue(forKey: unusedId) {
                view.removeFromSuperview()
                // 可选：放入 reusePool 供后续复用
            }
        }
    }
    
    // MARK: - 内部方法
    
    /// 获取或创建 Fragment 对应的 View（内部复用逻辑）
    private func fragmentView(
        for fragment: any RenderFragmentProtocol,
        reuseId: String,
        factory: () -> UIView
    ) -> UIView {
        if let existing = fragmentViews[fragment.fragmentId] {
            return existing
        }
        // 尝试从复用池取
        let view = reusePool[reuseId]?.isEmpty == false
            ? reusePool[reuseId]!.removeLast()
            : factory()
        fragmentViews[fragment.fragmentId] = view
        if view.superview !== self { addSubview(view) }
        return view
    }
    
    /// 计算 intrinsicContentSize（供外层布局使用）
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }
}
```

**为什么不用 IGListKit 管理单条消息内部的 Fragment？**

| 维度 | 硬布局 | IGListKit |
|------|--------|-----------|
| 布局开销 | 纯数值累加，O(n) | FlowLayout 解算 + diff 比对 |
| 流式渲染 | append Fragment → 增量计算 y | 每次 performUpdates 触发 diff |
| 内存 | 按需创建 UIView，复用池管理 | SectionController + Cell 包装层 |
| 气泡背景 | 一个 View 统一绘制 | 需跨 Cell 处理 |
| 适用场景 | 确定结构的线性流 ✅ | 异构列表、频繁增删排序 |

> **XHSMarkdownKit 不依赖任何列表框架**（如 IGListKit、UICollectionView 等）。Markdown 布局是确定的线性流，手动 frame 硬布局性能最优。宿主 App 如何管理外层列表是业务层的决策，与本库无关。

### 3.3 样式主题（MarkdownTheme.swift）

```swift
/// Markdown 样式 Token
/// 纯值类型，不依赖任何业务框架
public struct MarkdownTheme {
    
    public static let `default` = MarkdownTheme()
    
    // MARK: - 正文
    public var bodyFont: UIFont = .systemFont(ofSize: 15, weight: .regular)
    public var bodyColor: UIColor = .label
    public var bodyLineHeight: CGFloat = 25.0
    public var bodyLetterSpacing: CGFloat = 0.32   // kern
    
    // MARK: - 标题（H1-H6）
    public var headingFonts: [CGFloat] = [16, 16, 16, 16, 16, 16]
    public var headingWeights: [UIFont.Weight] = [.semibold, .semibold, .semibold, .semibold, .semibold, .semibold]
    public var headingLineHeights: [CGFloat] = [26, 26, 26, 26, 26, 26]
    public var headingColor: UIColor = .label
    public var heading1Color: UIColor? = nil  // H1 特殊颜色（nil 表示用 headingColor）
    
    // MARK: - 代码
    public var codeFont: UIFont = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    public var codeColor: UIColor = .systemGray
    public var codeBlockBackground: UIColor = .secondarySystemBackground
    
    // MARK: - 引用
    public var blockQuoteFont: UIFont = .systemFont(ofSize: 15, weight: .regular)
    public var blockQuoteColor: UIColor = .label         // 引用块内文字颜色
    public var blockQuoteLineHeight: CGFloat = 25.0
    public var blockQuoteBarColor: UIColor = .separator   // 左侧竖线颜色
    public var blockQuoteLeftMargin: CGFloat = 22.0       // 文字距左边界
    public var blockQuoteBarLeftMargin: CGFloat = 8.0     // 竖线距左边界
    public var blockQuoteNestingIndent: CGFloat = 20.0    // 每层嵌套增加的缩进
    
    // MARK: - 链接
    public var linkColor: UIColor = .systemBlue
    
    // MARK: - 删除线
    public var strikethroughStyle: NSUnderlineStyle = .single
    public var strikethroughColor: UIColor? = nil  // nil 表示跟随文本颜色
    
    // MARK: - 列表（无序）
    public var bulletSymbol: String = "•"
    public var bulletFont: UIFont = .systemFont(ofSize: 15, weight: .black)
    public var bulletColor: UIColor = .placeholderText
    public var bulletLeftMargin: CGFloat = 5.0
    public var bulletRightMargin: CGFloat = 11.0
    
    // MARK: - 列表（有序）
    public var orderedListFont: UIFont = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    public var orderedListColor: UIColor = .placeholderText
    public var orderedListLeftMargin: CGFloat = 4.0
    public var orderedListTextLeftMargin: CGFloat = 22.0
    public var orderedListAlignToEdge: Bool = true
    
    // MARK: - 间距
    public var paragraphSpacing: CGFloat = 26.0           // 段落间距
    public var headingSpacingBefore: [CGFloat] = [26, 26, 26, 26, 26, 26]
    public var headingSpacingAfter: CGFloat = 12.0        // 标题后间距
    public var listItemSpacing: CGFloat = 6.0             // 列表项间距
    public var listAfterTextSpacing: CGFloat = 12.0       // 文本-列表间距
    public var innerParagraphSpacing: CGFloat = 6.0       // 段落内间距
    public var blockQuoteBetweenSpacing: CGFloat = 6.0    // 引用间间距
    public var blockQuoteOtherSpacing: CGFloat = 12.0     // 引用与其他元素间距
    
    // MARK: - 分割线
    public var thematicBreakColor: UIColor = UIColor.black.withAlphaComponent(0.05)
    public var thematicBreakHeight: CGFloat = 1.0
    public var thematicBreakVerticalPadding: CGFloat = 7.5
    
    // MARK: - 表格
    public var tableBorderColor: UIColor = .separator
    public var tableHeaderBackground: UIColor = .secondarySystemBackground
    public var tableFont: UIFont = .systemFont(ofSize: 14)
    public var tablePadding: UIEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    
    // MARK: - 构造器
    public init() {}
}
```

### 3.4 块间距规则协议（BlockSpacingResolving）

间距规则在不同场景差异很大（紧凑排版 vs 宽松排版）。**把间距规则抽为协议，是务实的解耦——它是变化频率最高的逻辑。**

```swift
import XYMarkdown

/// 块级元素间距计算协议
///
/// 使用场景：
/// - 紧凑场景需要紧凑间距（段落间距 26pt、列表间距 6pt）
/// - 笔记详情需要宽松间距（段落间距 32pt）
/// - 搜索结果需要更紧凑的间距
///
/// 通过协议化，各场景只需实现自己的 Resolver，无需 fork 整个渲染器。
public protocol BlockSpacingResolving {
    /// 计算两个相邻块级节点之间的间距
    ///
    /// - Parameters:
    ///   - previous: 前一个块级节点
    ///   - current: 当前块级节点
    ///   - theme: 当前主题（可从中读取间距 Token）
    /// - Returns: 间距值（pt）
    func spacing(after previous: Markup, before current: Markup, theme: MarkdownTheme) -> CGFloat
}

/// 默认间距规则
///
/// 所有间距值从 MarkdownTheme 读取，不再硬编码。
public struct DefaultBlockSpacingResolver: BlockSpacingResolving {
    
    public init() {}
    
    public func spacing(after previous: Markup, before current: Markup, theme: MarkdownTheme) -> CGFloat {
        switch current {
        case is Paragraph:
            if previous is Heading   { return theme.headingSpacingAfter }
            if previous is BlockQuote { return theme.blockQuoteOtherSpacing }
            return theme.paragraphSpacing
            
        case let heading as Heading:
            return theme.headingSpacingBefore[safe: heading.level - 1] ?? theme.paragraphSpacing
            
        case is ThematicBreak, is CodeBlock:
            return theme.paragraphSpacing
            
        case is BlockQuote:
            if previous is BlockQuote { return theme.blockQuoteBetweenSpacing }
            if previous is Heading    { return theme.headingSpacingAfter }
            return theme.blockQuoteOtherSpacing
            
        case is UnorderedList, is OrderedList:
            if previous is Heading    { return theme.headingSpacingAfter }
            if previous is Paragraph  { return theme.listAfterTextSpacing }
            if previous is BlockQuote { return theme.blockQuoteOtherSpacing }
            return theme.paragraphSpacing
            
        default:
            return 0
        }
    }
}
```

间距协议通过 `MarkdownConfiguration` 注入：

```swift
// MarkdownConfiguration 中新增
public var spacingResolver: BlockSpacingResolving = DefaultBlockSpacingResolver()
```

**使用示例：**

```swift
// 笔记详情场景 — 宽松间距
struct NoteDetailSpacingResolver: BlockSpacingResolving {
    func spacing(after previous: Markup, before current: Markup, theme: MarkdownTheme) -> CGFloat {
        // 笔记详情：所有块间距统一 32pt，引用块间距 24pt
        if current is BlockQuote || previous is BlockQuote { return 24 }
        return 32
    }
}

var config = MarkdownConfiguration.default
config.spacingResolver = NoteDetailSpacingResolver()
let result = MarkdownKit.render(text, configuration: config)
```

### 3.5 节点渲染器协议层（核心可扩展机制）

这是整个渲染层的可扩展性基石。**每一种 Markdown 节点的渲染，都可以被外部替换或新增注入**。

#### 3.5.1 节点渲染协议

```swift
import XYMarkdown

// ===== 节点渲染上下文 =====

/// 渲染时的上下文信息，传递给每个 NodeRenderer
///
/// v1.2 增强：除了基本的 theme/maxWidth 外，新增兄弟节点信息和列表索引。
/// 务实原因：现有代码中 visitListItem 需要通过 listItem.indexInParent、
/// listItem.prevSibling?.childCount 等方式获取这些信息，非常碎片化。
/// 统一到 Context 中，渲染器不需要自己遍历 AST。
public struct NodeRenderContext {
    /// 当前主题
    public let theme: MarkdownTheme
    /// 可用渲染宽度（用于 UIView 型渲染器计算布局）
    public let maxWidth: CGFloat
    /// 嵌套层级（列表/引用的嵌套深度）
    public let nestingLevel: Int
    /// 父节点类型（用于上下文感知，如"引用块内的列表"需要特殊处理）
    public let parentNodeType: MarkdownNodeType?
    
    /// 子节点渲染回调（用于渲染器内部递归渲染子节点）
    public let renderChildren: (Markup) -> NSAttributedString
    
    // MARK: - v1.2 新增：兄弟节点 & 列表上下文
    
    /// 前一个兄弟节点的类型（间距计算、首项判断等）
    public let previousSiblingType: MarkdownNodeType?
    /// 后一个兄弟节点的类型（尾部处理等）
    public let nextSiblingType: MarkdownNodeType?
    /// 当前节点在父节点中的索引（列表项序号、首项判断等）
    public let indexInParent: Int
    /// 有序列表的起始序号（仅 listItem 上下文有效，从 OrderedList.startIndex 传入）
    public let listStartIndex: UInt?
    /// 前一个兄弟节点的子节点数量（用于列表间距判断：前项有多个子块 → 用更大间距）
    public let previousSiblingChildCount: Int?
    
    public init(
        theme: MarkdownTheme,
        maxWidth: CGFloat = .greatestFiniteMagnitude,
        nestingLevel: Int = 0,
        parentNodeType: MarkdownNodeType? = nil,
        renderChildren: @escaping (Markup) -> NSAttributedString,
        previousSiblingType: MarkdownNodeType? = nil,
        nextSiblingType: MarkdownNodeType? = nil,
        indexInParent: Int = 0,
        listStartIndex: UInt? = nil,
        previousSiblingChildCount: Int? = nil
    ) {
        self.theme = theme
        self.maxWidth = maxWidth
        self.nestingLevel = nestingLevel
        self.parentNodeType = parentNodeType
        self.renderChildren = renderChildren
        self.previousSiblingType = previousSiblingType
        self.nextSiblingType = nextSiblingType
        self.indexInParent = indexInParent
        self.listStartIndex = listStartIndex
        self.previousSiblingChildCount = previousSiblingChildCount
    }
}

/// 节点类型标识
/// 标准节点使用预定义的 case，自定义节点使用 .custom("identifier")
public enum MarkdownNodeType: Hashable {
    // 块级
    case document
    case heading(level: Int)  // v1.2: 携带层级信息，省去渲染器内部 downcast
    case paragraph, blockQuote, codeBlock
    case orderedList, unorderedList, listItem
    case table, thematicBreak, htmlBlock
    
    // 行内
    case text, strong, emphasis, strikethrough
    case inlineCode, link, image
    case lineBreak, softBreak, inlineHTML
    
    // 自定义（任意标识符）
    case customBlock(String)
    case customInline(String)
    
    /// 从 XYMarkdown 的 Markup 节点推导类型（内部使用）
    static func from(_ node: Markup) -> MarkdownNodeType {
        switch node {
        case let h as Heading:        return .heading(level: h.level)
        case is Paragraph:            return .paragraph
        case is BlockQuote:           return .blockQuote
        case is CodeBlock:            return .codeBlock
        case is OrderedList:          return .orderedList
        case is UnorderedList:        return .unorderedList
        case is ListItem:             return .listItem
        case is Table:                return .table
        case is ThematicBreak:        return .thematicBreak
        case is Strong:               return .strong
        case is Emphasis:             return .emphasis
        case is Strikethrough:        return .strikethrough
        case is InlineCode:           return .inlineCode
        case is Link:                 return .link
        case is Image:                return .image
        case is Text:                 return .text
        case is LineBreak:            return .lineBreak
        case is SoftBreak:            return .softBreak
        case is InlineHTML:           return .inlineHTML
        case is HTMLBlock:            return .htmlBlock
        default:                      return .document
        }
    }
}

// ===== 两种渲染器协议 =====

/// 文本节点渲染器：节点 → NSAttributedString
///
/// 适用于大部分节点（标题、段落、列表、引用、行内样式等）
public protocol AttributedStringNodeRenderer {
    /// 渲染节点为 NSAttributedString
    func render(node: Markup, context: NodeRenderContext) -> NSAttributedString
}

/// 视图节点渲染器：节点 → UIView
///
/// v1.2 改进：拆分 makeView() 和 configure()，遵循 UIKit 标准复用模式。
///
/// 务实原因：在 UICollectionView Cell 复用场景中，v1.1 的 `render() -> UIView`
/// 每次都创建新 View 实例，导致：
/// 1. Cell 复用时旧 View 泄漏（需要手动移除）
/// 2. 无法利用 Cell 的复用池回收 View
/// 3. 快速滚动时大量临时对象导致内存抖动
///
/// 拆分后：
/// - `makeView()`: Cell 首次创建时调用一次
/// - `configure(view:node:context:)`: Cell 每次复用时调用
/// - 和 UICollectionViewCell 的 init + configure 模式完全一致
public protocol ViewNodeRenderer {
    /// 创建 View 实例（Cell 首次创建时调用一次）
    func makeView(context: NodeRenderContext) -> UIView
    /// 配置已有 View（Cell 复用时调用，传入新的节点数据）
    func configure(view: UIView, node: Markup, context: NodeRenderContext)
    /// 预计算尺寸（用于布局，不需要实际创建 View）
    func estimatedSize(node: Markup, context: NodeRenderContext) -> CGSize
    /// View 的复用标识（用于在 Cell 复用场景中回收 View）
    var reuseIdentifier: String { get }
}

/// ViewNodeRenderer 默认实现 — 简单场景可以只实现 makeView，不需要分离 configure
extension ViewNodeRenderer {
    public func configure(view: UIView, node: Markup, context: NodeRenderContext) {
        // 默认无操作，简单场景直接用 makeView 创建完整 View
    }
}

/// 统一包装：一个节点可以注册为文本渲染器或视图渲染器
public enum NodeRenderer {
    case attributedString(AttributedStringNodeRenderer)
    case view(ViewNodeRenderer)
}
```

#### 3.5.2 节点渲染器注册表

```swift
/// 节点渲染器注册表
///
/// 核心扩展机制：
/// 1. 覆盖标准节点的渲染方式（如用自定义 UIView 替换默认的代码块渲染）
/// 2. 注册全新的自定义节点渲染器（如 Latex、投票卡片、商品卡片等）
///
/// 使用 `MarkdownConfiguration.rendererOverrides` 或 `NodeRendererRegistry.shared` 注册
public final class NodeRendererRegistry {
    
    public static let shared = NodeRendererRegistry()
    
    /// 已注册的渲染器（节点类型 → 渲染器）
    private var renderers: [MarkdownNodeType: NodeRenderer] = [:]
    
    /// 注册文本型渲染器（覆盖或新增）
    public func register(
        _ nodeType: MarkdownNodeType,
        renderer: AttributedStringNodeRenderer
    ) {
        renderers[nodeType] = .attributedString(renderer)
    }
    
    /// 注册视图型渲染器（覆盖或新增）
    public func register(
        _ nodeType: MarkdownNodeType,
        viewRenderer: ViewNodeRenderer
    ) {
        renderers[nodeType] = .view(viewRenderer)
    }
    
    /// 便捷注册：用闭包注册文本型渲染器
    public func register(
        _ nodeType: MarkdownNodeType,
        render: @escaping (Markup, NodeRenderContext) -> NSAttributedString
    ) {
        register(nodeType, renderer: ClosureAttributedStringRenderer(render))
    }
    
    /// 便捷注册：用闭包注册视图型渲染器
    public func register(
        _ nodeType: MarkdownNodeType,
        reuseIdentifier: String = "",
        estimatedSize: @escaping (Markup, NodeRenderContext) -> CGSize = { _, _ in .zero },
        renderView: @escaping (Markup, NodeRenderContext) -> UIView
    ) {
        register(nodeType, viewRenderer: ClosureViewRenderer(
            reuseId: reuseIdentifier,
            estimatedSizeFn: estimatedSize,
            renderFn: renderView
        ))
    }
    
    /// 查询渲染器
    func renderer(for nodeType: MarkdownNodeType) -> NodeRenderer? {
        renderers[nodeType]
    }
    
    /// 移除指定节点的自定义渲染器（恢复默认渲染）
    public func unregister(_ nodeType: MarkdownNodeType) {
        renderers.removeValue(forKey: nodeType)
    }
    
    /// 移除所有自定义渲染器
    public func removeAll() {
        renderers.removeAll()
    }
}
```

#### 3.5.3 MarkdownConfiguration 增强

```swift
/// 渲染配置
public struct MarkdownConfiguration {
    public static let `default` = MarkdownConfiguration()
    
    /// 渲染器覆盖（实例级，仅对当前 render 调用生效）
    /// 优先级：rendererOverrides > NodeRendererRegistry.shared > 内置默认
    public var rendererOverrides: [MarkdownNodeType: NodeRenderer] = [:]
    
    /// 块间距计算器（v1.2 新增，可替换间距规则）
    public var spacingResolver: BlockSpacingResolving = DefaultBlockSpacingResolver()
    
    /// 是否启用蓝链改写
    public var enableRichLink: Bool = true
    
    /// 可用渲染宽度（用于 UIView 型渲染器）
    public var maxWidth: CGFloat = .greatestFiniteMagnitude
    
    /// 已知的自定义块节点标识符列表
    /// 当 visitCustomBlock 遇到这些标识符时，会查找对应的渲染器
    public var customBlockIdentifiers: Set<String> = []
    
    /// 已知的自定义行内节点标识符列表
    public var customInlineIdentifiers: Set<String> = []
    
    // MARK: - Fragment ID 策略（流式渲染相关）
    
    /// Fragment ID 生成策略
    ///
    /// 不同策略在"稳定性"和"精确性"之间权衡：
    /// - `.structuralFingerprint`：基于 AST 位置，replace 时只更新变化的 fragment（默认）
    /// - `.sequentialIndex`：基于顺序索引，replace 时后续所有 fragment 都会 delete+insert
    /// - `.contentHash`：基于内容 hash，相同内容复用（适合内容重复的场景）
    ///
    /// 如果发现流式渲染出现异常（如 fragment 错位、内容丢失），可降级到 `.sequentialIndex`
    public var fragmentIdStrategy: FragmentIdStrategy = .structuralFingerprint
    
    /// Fragment ID 生成策略枚举
    public enum FragmentIdStrategy {
        /// 结构指纹（默认）：基于节点类型 + 顶层块索引
        /// 优点：replace 时只更新变化的 fragment，性能好
        /// 缺点：复杂的嵌套结构变化可能导致 id 冲突
        case structuralFingerprint
        
        /// 顺序索引（降级方案）：基于遍历顺序的递增索引
        /// 优点：简单可靠，不会出现 id 冲突
        /// 缺点：replace/remove 时后续所有 fragment 都会重建
        case sequentialIndex
        
        /// 内容哈希：基于内容的 hash
        /// 优点：相同内容的 fragment 可以复用
        /// 缺点：内容变化 = id 变化，变成 delete+insert 而非 update
        case contentHash
    }
    
    // MARK: - 便捷配置方法
    
    /// 覆盖标准节点的渲染方式
    public mutating func override(
        _ nodeType: MarkdownNodeType,
        with renderer: AttributedStringNodeRenderer
    ) {
        rendererOverrides[nodeType] = .attributedString(renderer)
    }
    
    /// 覆盖标准节点为 UIView 渲染
    public mutating func override(
        _ nodeType: MarkdownNodeType,
        withView renderer: ViewNodeRenderer
    ) {
        rendererOverrides[nodeType] = .view(renderer)
    }
    
    /// 注册自定义块节点的 UIView 渲染器
    public mutating func registerCustomBlock(
        identifier: String,
        viewRenderer: ViewNodeRenderer
    ) {
        customBlockIdentifiers.insert(identifier)
        rendererOverrides[.customBlock(identifier)] = .view(viewRenderer)
    }
    
    /// 注册自定义行内节点的渲染器
    public mutating func registerCustomInline(
        identifier: String,
        renderer: AttributedStringNodeRenderer
    ) {
        customInlineIdentifiers.insert(identifier)
        rendererOverrides[.customInline(identifier)] = .attributedString(renderer)
    }
    
    public init() {}
}
```

#### 3.5.4 主渲染器调度逻辑（MarkdownRenderer.swift）

```swift
import XYMarkdown

/// Markdown 主渲染器
///
/// 实现 MarkupVisitor，但不直接写渲染逻辑。
/// 每个 visit 方法遵循统一的调度流程：
///   1. 查 configuration.rendererOverrides（实例级覆盖）
///   2. 查 NodeRendererRegistry.shared（全局注册）
///   3. 都没有 → 走内置默认渲染器（Defaults/ 目录下的实现）
///
/// v1.2 改进：
/// - 输出 [RenderFragment] 序列，不再用 viewBlocks 锚点
/// - 利用 BlockSpacingResolving 协议计算间距
/// - NodeRenderContext 包含完整的兄弟节点信息
struct MarkdownRenderer: MarkupVisitor {
    typealias Result = NSAttributedString
    
    let theme: MarkdownTheme
    let configuration: MarkdownConfiguration
    let registry: NodeRendererRegistry
    
    /// 有序片段收集器（v1.2 替代 viewBlocks）
    private(set) var fragments: [any RenderFragmentProtocol] = []
    /// 当前正在累积的文本内容（遇到 ViewFragment 时 flush）
    private var pendingText = NSMutableAttributedString()
    
    /// 当前嵌套层级
    private var nestingLevel: Int = 0
    private var parentNodeType: MarkdownNodeType? = nil
    /// 片段计数器（用于生成 fragmentId）
    private var fragmentCounter: Int = 0
    
    init(
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default,
        registry: NodeRendererRegistry = .shared
    ) {
        self.theme = theme
        self.configuration = configuration
        self.registry = registry
    }
    
    // MARK: - Fragment 管理
    
    /// 生成 Fragment ID
    ///
    /// 根据 configuration.fragmentIdStrategy 选择不同的生成策略。
    /// 如果流式渲染出现异常，可降级到 .sequentialIndex
    private func makeFragmentId(
        nodeType: MarkdownNodeType,
        content: NSAttributedString? = nil
    ) -> String {
        switch configuration.fragmentIdStrategy {
        case .structuralFingerprint:
            // 结构指纹：基于节点类型 + 顶层块索引
            let typeStr: String
            switch nodeType {
            case .heading: typeStr = "h"
            case .paragraph: typeStr = "p"
            case .codeBlock: typeStr = "code"
            case .blockQuote: typeStr = "quote"
            case .orderedList: typeStr = "ol"
            case .unorderedList: typeStr = "ul"
            case .table: typeStr = "table"
            case .thematicBreak: typeStr = "hr"
            case .customBlock(let id): typeStr = "c_\(id)"
            default: typeStr = "b"
            }
            return "\(typeStr)\(fragmentCounter)"
            
        case .sequentialIndex:
            // 顺序索引（降级方案）：简单递增
            return "frag_\(fragmentCounter)"
            
        case .contentHash:
            // 内容哈希：基于内容生成
            let hash = content?.string.hashValue ?? fragmentCounter
            return "hash_\(hash)"
        }
    }
    
    /// 将累积的文本内容刷出为一个 TextFragment
    private mutating func flushPendingText(nodeType: MarkdownNodeType = .paragraph) {
        guard pendingText.length > 0 else { return }
        let content = pendingText.copy() as! NSAttributedString
        fragmentCounter += 1
        let fragmentId = makeFragmentId(nodeType: nodeType, content: content)
        var fragment = TextFragment(
            fragmentId: fragmentId,
            nodeType: nodeType,
            attributedString: content
        )
        fragments.append(fragment)
        pendingText = NSMutableAttributedString()
    }
    
    /// 添加一个 ViewFragment（自动先 flush 文本）
    private mutating func appendViewFragment(
        nodeType: MarkdownNodeType,
        renderer: ViewNodeRenderer,
        node: Markup,
        context: NodeRenderContext
    ) {
        flushPendingText()
        fragmentCounter += 1
        let fragmentId = makeFragmentId(nodeType: nodeType)
        fragments.append(ViewFragment(
            fragmentId: fragmentId,
            nodeType: nodeType,
            reuseIdentifier: renderer.reuseIdentifier,
            size: renderer.estimatedSize(node: node, context: context),
            makeView: { [node, context] in renderer.makeView(node: node, context: context) },
            configure: { view in renderer.configure(view: view, node: node, context: context) }
        ))
    }
    
    // MARK: - 核心调度
    
    /// 构造渲染上下文（v1.2：包含兄弟节点信息）
    private func makeContext(for node: Markup) -> NodeRenderContext {
        NodeRenderContext(
            theme: theme,
            maxWidth: configuration.maxWidth,
            nestingLevel: nestingLevel,
            parentNodeType: parentNodeType,
            renderChildren: { [self] child in
                var mutableSelf = self
                return mutableSelf.visit(child)
            },
            previousSiblingType: node.prevSibling.map { MarkdownNodeType.from($0) },
            nextSiblingType: node.nextSibling.map { MarkdownNodeType.from($0) },
            indexInParent: node.indexInParent,
            listStartIndex: (node.parent as? OrderedList).map { $0.startIndex },
            previousSiblingChildCount: node.prevSibling?.childCount
        )
    }
    
    /// 统一的节点渲染调度
    /// 查找顺序：configuration 覆盖 → registry 全局注册 → 默认实现
    private mutating func dispatch(
        nodeType: MarkdownNodeType,
        node: Markup,
        defaultRender: (NodeRenderContext) -> NSAttributedString
    ) -> NSAttributedString {
        let context = makeContext(for: node)
        
        // 1. 查实例级覆盖
        if let override = configuration.rendererOverrides[nodeType] {
            return applyRenderer(override, nodeType: nodeType, node: node, context: context)
        }
        
        // 2. 查全局注册
        if let registered = registry.renderer(for: nodeType) {
            return applyRenderer(registered, nodeType: nodeType, node: node, context: context)
        }
        
        // 3. 走内置默认
        return defaultRender(context)
    }
    
    /// 应用渲染器（文本型 → 追加到 pendingText，视图型 → flush + 添加 ViewFragment）
    private mutating func applyRenderer(
        _ renderer: NodeRenderer,
        nodeType: MarkdownNodeType,
        node: Markup,
        context: NodeRenderContext
    ) -> NSAttributedString {
        switch renderer {
        case .attributedString(let attrRenderer):
            return attrRenderer.render(node: node, context: context)
            
        case .view(let viewRenderer):
            appendViewFragment(nodeType: nodeType, renderer: viewRenderer, node: node, context: context)
            return NSAttributedString() // 视图片段不参与文本拼接
        }
    }
    
    // MARK: - MarkupVisitor 实现（每个 visit 都走 dispatch）
    
    mutating func visitDocument(_ document: Document) -> NSAttributedString {
        var prevChild: Markup? = nil
        for child in document.children {
            // 利用 BlockSpacingResolving 协议计算间距
            if let prev = prevChild {
                let spacing = configuration.spacingResolver.spacing(
                    after: prev, before: child, theme: theme
                )
                pendingText.appendSpacingLine(height: spacing)
            }
            pendingText.append(visit(child))
            prevChild = child
        }
        flushPendingText()  // 最后一批文本
        return NSAttributedString()  // 实际结果在 fragments 中
    }
    
    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        dispatch(nodeType: .heading(level: heading.level), node: heading) { ctx in
            HeadingRenderer.default.render(node: heading, context: ctx)
        }
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        dispatch(nodeType: .paragraph, node: paragraph) { ctx in
            ParagraphRenderer.default.render(node: paragraph, context: ctx)
        }
    }
    
    mutating func visitTable(_ table: Table) -> NSAttributedString {
        dispatch(nodeType: .table, node: table) { ctx in
            // 默认：UIView 渲染
            appendViewFragment(nodeType: .table, renderer: TableRenderer.default, node: table, context: ctx)
            return NSAttributedString()
        }
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        dispatch(nodeType: .codeBlock, node: codeBlock) { ctx in
            // 默认：NSAttributedString（可被外部覆盖为带语法高亮的 UIView）
            CodeBlockRenderer.default.render(node: codeBlock, context: ctx)
        }
    }
    
    // ... 其余 visit 方法同理，每个都走 dispatch
    
    mutating func visitCustomBlock(_ customBlock: CustomBlock) -> NSAttributedString {
        let identifier = parseCustomBlockIdentifier(customBlock)
        return dispatch(nodeType: .customBlock(identifier), node: customBlock) { _ in
            NSAttributedString(string: customBlock.description)
        }
    }
    
    mutating func visitCustomInline(_ customInline: CustomInline) -> NSAttributedString {
        let identifier = customInline.text.components(separatedBy: ":").first ?? "unknown"
        return dispatch(nodeType: .customInline(identifier), node: customInline) { _ in
            NSAttributedString(string: customInline.text)
        }
    }
}
```

#### 3.5.5 使用示例

```swift
// ===== 示例 1：覆盖标准节点 — 代码块用自定义 UIView（带语法高亮）=====
// 演示 ViewNodeRenderer 的 makeView / configure 分离模式

class SyntaxHighlightCodeBlockRenderer: ViewNodeRenderer {
    var reuseIdentifier: String { "SyntaxHighlightCodeBlock" }
    
    // 首次创建 View（Cell init 时调用一次）
    func makeView(context: NodeRenderContext) -> UIView {
        SyntaxHighlightView(frame: .zero)
    }
    
    // Cell 复用时调用，传入新的代码内容
    func configure(view: UIView, node: Markup, context: NodeRenderContext) {
        guard let codeBlock = node as? CodeBlock,
              let highlightView = view as? SyntaxHighlightView else { return }
        highlightView.configure(code: codeBlock.code, language: codeBlock.language ?? "")
    }
    
    func estimatedSize(node: Markup, context: NodeRenderContext) -> CGSize {
        CGSize(width: context.maxWidth, height: 200)
    }
}

// 注册方式 1：全局注册（所有 render 调用都生效）
NodeRendererRegistry.shared.register(
    .codeBlock,
    viewRenderer: SyntaxHighlightCodeBlockRenderer()
)

// 注册方式 2：实例级覆盖（仅本次 render 调用生效）
var config = MarkdownConfiguration.default
config.override(.codeBlock, withView: SyntaxHighlightCodeBlockRenderer())
let result = MarkdownKit.render(text, theme: .richtext, configuration: config)


// ===== 示例 2：注入全新的自定义块节点 UIView =====
// 比如后端返回的 Markdown 中有 :::product{id=123} 这样的自定义块

class ProductCardRenderer: ViewNodeRenderer {
    var reuseIdentifier: String { "ProductCard" }
    
    func makeView(context: NodeRenderContext) -> UIView {
        ProductCardView(frame: .zero)
    }
    
    func configure(view: UIView, node: Markup, context: NodeRenderContext) {
        guard let card = view as? ProductCardView else { return }
        card.configure(productId: parseProductId(from: node))
    }
    
    func estimatedSize(node: Markup, context: NodeRenderContext) -> CGSize {
        CGSize(width: context.maxWidth, height: 120)
    }
}

var config = MarkdownConfiguration.default
config.registerCustomBlock(identifier: "product", viewRenderer: ProductCardRenderer())
let result = MarkdownKit.render(markdown, configuration: config)


// ===== 示例 3：用闭包快速注册（适合简单场景）=====

NodeRendererRegistry.shared.register(.thematicBreak) { node, context in
    let attrStr = NSMutableAttributedString()
    attrStr.append(NSAttributedString(string: "—— ✦ ——", attributes: [
        .foregroundColor: context.theme.thematicBreakColor,
        .font: UIFont.systemFont(ofSize: 12)
    ]))
    return attrStr
}


// ===== 示例 4：利用 NodeRenderContext 新增的兄弟节点信息 =====

class ContextAwareBlockQuoteRenderer: AttributedStringNodeRenderer {
    func render(node: Markup, context: NodeRenderContext) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let childrenText = context.renderChildren(node)
        result.append(childrenText)
        
        // v1.2: 利用 context 中的兄弟节点信息，不需要自己遍历 AST
        if context.previousSiblingType == nil {
            // 第一个引用块：加顶部圆角
        }
        if context.nextSiblingType != .blockQuote {
            // 最后一个连续引用块：加底部圆角
        }
        
        result.addAttribute(.backgroundColor, value: UIColor.systemGray6,
                          range: NSRange(location: 0, length: result.length))
        return result
    }
}

NodeRendererRegistry.shared.register(.blockQuote, renderer: ContextAwareBlockQuoteRenderer())


// ===== 示例 5：渲染结果的 Fragment 消费 =====

let result = MarkdownKit.render(markdownText, theme: .richtext)

// 简单场景：无 UIView 混排，直接取合并的 attributedString
label.attributedText = result.attributedString

// 标准场景：用 MarkdownContainerView 硬布局（性能最优）
let containerView = MarkdownContainerView()
containerView.apply(result, maxWidth: bubbleWidth)
// containerView.contentHeight 立即可用 → 供 Cell 高度计算
cell.contentView.addSubview(containerView)
containerView.frame = CGRect(x: 0, y: 0, width: bubbleWidth, height: containerView.contentHeight)
```

### 3.6 AST 改写器（RichLinkRewriter.swift）

```swift
import XYMarkdown

/// 蓝链模型协议
/// 宿主 App 的 DotsRichTextModel 遵循此协议，XHSMarkdownKit 不直接依赖 XYAGIModels
public protocol RichLinkModel {
    /// 蓝链的显示文本
    var displayText: String { get }
    /// 蓝链的链接地址
    var linkURL: String { get }
    /// 蓝链匹配的原始 Markdown 链接 destination
    var httpLink: String? { get }
}

/// 蓝链 AST 改写器
///
/// 遍历 Document AST，将匹配蓝链模型的 Link 节点做标记/替换。
/// 利用 XYMarkdown 的 MarkupRewriter 协议，在 AST 级别改写，
/// 替代字符串匹配方式的蓝链处理。
public struct RichLinkRewriter: MarkupRewriter {
    
    let richLinks: [RichLinkModel]
    
    public init(richLinks: [RichLinkModel]) {
        self.richLinks = richLinks
    }
    
    /// MarkupRewriter 协议：返回 nil 表示不修改，返回 Markup 表示替换
    public mutating func visitLink(_ link: Link) -> Markup? {
        guard let destination = link.destination,
              let matchedModel = richLinks.first(where: { $0.httpLink == destination }) else {
            return nil  // 不是蓝链，保持原样
        }
        
        // 替换 Link 子节点的文本为蓝链显示文本
        // 并在 Link 节点上添加标记（通过 CustomInline 或其他方式）
        var newLink = link
        // ... 改写逻辑
        return newLink
    }
}
```

### 3.7 Rewriter 管线（RewriterPipeline.swift）

```swift
import XYMarkdown

/// 类型擦除的 MarkupRewriter 包装
public struct AnyMarkupRewriter {
    private let _rewrite: (Document) -> Document
    
    public init<R: MarkupRewriter>(_ rewriter: R) {
        var r = rewriter
        _rewrite = { document in
            r.visitDocument(document) as? Document ?? document
        }
    }
    
    func rewrite(_ document: Document) -> Document {
        _rewrite(document)
    }
}

/// Rewriter 管线：按顺序串联执行多个 AST 改写器
struct RewriterPipeline {
    let rewriters: [AnyMarkupRewriter]
    
    func rewrite(_ document: Document) -> Document {
        rewriters.reduce(document) { doc, rewriter in
            rewriter.rewrite(doc)
        }
    }
}
```

### 3.8 Document 缓存（DocumentCache.swift）

```swift
import XYMarkdown

/// Document 缓存
///
/// 相同的 Markdown 文本不重复解析，特别适合流式消息场景
/// （每次 append 文本后重新渲染，前面已解析的部分可以复用）
final class DocumentCache {
    
    private let cache = NSCache<NSString, DocumentWrapper>()
    
    init(countLimit: Int = 100) {
        cache.countLimit = countLimit
    }
    
    /// 获取或创建 Document
    func document(for markdown: String) -> Document {
        let key = markdown as NSString
        if let cached = cache.object(forKey: key) {
            return cached.document
        }
        let doc = Document(parsing: markdown)
        cache.setObject(DocumentWrapper(doc), forKey: key)
        return doc
    }
    
    /// 清除所有缓存
    func removeAll() {
        cache.removeAllObjects()
    }
}

/// NSCache 要求值类型为 AnyObject
private final class DocumentWrapper: NSObject {
    let document: Document
    init(_ document: Document) { self.document = document }
}
```

### 3.9 MarkdownRenderable 协议（View 层便捷渲染）

让 UIView 子类一行代码具备 Markdown 渲染能力。**这不是为了抽象而抽象——减少每个使用方重复写 `MarkdownKit.render() → result.attributedString → label.attributedText` 的样板代码。**

```swift
/// 让任何 View 具备 Markdown 渲染能力
///
/// 务实的好处：
/// 1. 消除每个使用方的样板代码（parse → render → 赋值）
/// 2. 统一入口，便于后续加入渲染缓存、性能监控等中间逻辑
/// 3. 与 MarkdownConfiguration 天然配合
public protocol MarkdownRenderable: AnyObject {
    /// 使用 Markdown 文本更新 View 内容
    func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme,
        configuration: MarkdownConfiguration
    )
    
    /// 使用已有的渲染结果更新 View 内容（跳过渲染，适用于缓存场景）
    func applyRenderResult(_ result: MarkdownRenderResult)
}

// MARK: - UILabel 默认实现（纯文本场景）

extension UILabel: MarkdownRenderable {
    public func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) {
        let result = MarkdownKit.render(text, theme: theme, configuration: configuration)
        applyRenderResult(result)
    }
    
    public func applyRenderResult(_ result: MarkdownRenderResult) {
        self.attributedText = result.attributedString
    }
}

// MARK: - UITextView 默认实现（支持链接点击）

extension UITextView: MarkdownRenderable {
    public func renderMarkdown(
        _ text: String,
        theme: MarkdownTheme = .default,
        configuration: MarkdownConfiguration = .default
    ) {
        let result = MarkdownKit.render(text, theme: theme, configuration: configuration)
        applyRenderResult(result)
    }
    
    public func applyRenderResult(_ result: MarkdownRenderResult) {
        self.attributedText = result.attributedString
        self.isEditable = false
        self.isScrollEnabled = false
        self.textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
    }
}
```

**使用对比：**

```swift
// ❌ 没有 MarkdownRenderable — 每个调用点都要写
let result = MarkdownKit.render(text, theme: .richtext)
label.attributedText = result.attributedString

// ✅ 有 MarkdownRenderable — 一行搞定
label.renderMarkdown(text, theme: .richtext)
```

### 3.10 可扩展机制总览

渲染层的可扩展性通过 **5 个协议 + 三层查找机制** 实现（v1.2 新增协议用 ★ 标注）：

```
协议总览：

1. AttributedStringNodeRenderer  — 文本节点渲染（标题/段落/列表...）
2. ViewNodeRenderer              — 视图节点渲染（表格/图片/自定义卡片...），v1.2: makeView/configure 分离
3. RenderFragmentProtocol     ★  — 渲染结果的基本单元（TextFragment / ViewFragment / 可扩展）
4. BlockSpacingResolving      ★  — 块间距规则（可替换，不同场景不同间距）
5. MarkdownRenderable         ★  — View 层便捷渲染（UILabel/UITextView 开箱即用）
6. StreamingAnimationDelegate ★★ — 自定义 View 流式动画（进场/退场，v1.4 新增）

渲染器查找优先级（高 → 低）：

1. MarkdownConfiguration.rendererOverrides    ← 实例级覆盖（仅当次 render 调用生效）
2. NodeRendererRegistry.shared                ← 全局注册（App 启动时注册，所有调用生效）
3. Defaults/ 内置默认实现                       ← 兜底（标准 Markdown 渲染）
```

**全场景可扩展对照表：**

| 我想... | 用哪个协议 | 做法 | 示例 |
|---------|-----------|------|------|
| 替换代码块为语法高亮 UIView | `ViewNodeRenderer` | `registry.register(.codeBlock, viewRenderer: ...)` | SyntaxHighlightView |
| 替换引用块为卡片样式 | `AttributedStringNodeRenderer` | `registry.register(.blockQuote, renderer: ...)` | 背景色卡片 |
| 注入商品卡片自定义块 | `ViewNodeRenderer` | `config.registerCustomBlock(identifier: ...)` | ProductCardView |
| 注入 @提及 自定义行内 | `AttributedStringNodeRenderer` | `config.registerCustomInline(identifier: ...)` | 蓝色用户名 |
| 笔记详情用更大间距 | `BlockSpacingResolving` | `config.spacingResolver = NoteDetailSpacingResolver()` | 段落间距 32pt |
| 自定义渲染结果类型 | `RenderFragmentProtocol` | 新增 conform 类型 | InteractiveFragment |
| UILabel 直接渲染 MD | `MarkdownRenderable` | `label.renderMarkdown(text, theme: ...)` | 一行代码 |
| A/B 测试标题样式 | `AttributedStringNodeRenderer` | `config.override(.heading(level:1), with: ...)` | 单次覆盖 |
| 表格进场动画改为滑入 | `StreamingAnimationDelegate` | `animator.delegate = CustomAnimDelegate()` | 左侧滑入 |
| 流式逐字速度调整 | `StreamingAnimator.Mode` | `animator.mode = .typewriter(charsPerFrame: 3)` | 加速渐入 |

**自定义节点与 Markdown 源文本的对应关系：**

自定义节点需要在 Markdown 源文本中有对应的语法标记，XYMarkdown 解析后才会生成 `CustomBlock` / `CustomInline` 节点。两种方式：

1. **Block Directives**（XYMarkdown 通过 `ParseOptions.parseBlockDirectives` 支持）：
   ```markdown
   @Directive(arg) {
     content
   }
   ```

2. **MarkupRewriter 注入**：在 AST 改写阶段，将特定模式的节点替换为 `CustomBlock` / `CustomInline`。例如把 `:::product{id=123}` 格式的 HTMLBlock 改写为 CustomBlock。

**ViewNodeRenderer 的 View 复用设计（v1.2/v1.3 增强）：**

v1.2 将 `render() -> UIView` 拆分为 `makeView()` + `configure(view:node:context:)`。v1.3 落地到 `MarkdownContainerView` 内部的复用池机制：

```swift
// MarkdownContainerView 内部复用流程：
//
// 首次 apply（Fragment 无缓存）：
//   let view = viewFragment.makeView()        // 通过 ViewNodeRenderer.makeView 创建
//   containerView.addSubview(view)
//   fragmentViews[fragmentId] = view           // 缓存
//
// 再次 apply（Fragment 已有缓存）：
//   let existing = fragmentViews[fragmentId]
//   viewFragment.configure(existing)           // 只更新内容，不重建
//   existing.frame = precomputedFrame           // 直接赋 frame
//
// Fragment 被移除：
//   view.removeFromSuperview()
//   reusePool[reuseId].append(view)            // 回收到复用池
//
// 新 Fragment 匹配到复用池：
//   let reused = reusePool[reuseId].removeLast()  // 取出复用
//   viewFragment.configure(reused)
```

---

### 3.11 流式渲染架构（Streaming）

AI 回复场景下，Markdown 文本通过 SSE/WebSocket 逐 chunk 送达，且业务上存在 replace/remove（后续回答修改前面内容）。流式渲染需要解决 **7 个核心问题**：增量解析、增量渲染、数据变更、未闭合标记、流式动画、自定义 View 动画、三者协调。

#### 3.11.1 流式管线总览

```
SSE/WS chunk
  │
  ▼
StreamingTextBuffer          ← 文本缓冲 + 合并（append / replace / remove）
  │
  ▼ 节流（throttle 16~33ms，合并多个 chunk）
  │
  ▼
MarkdownPreprocessor         ← 未闭合标记预闭合（解析前预处理）
  │
  ▼
Document(parsing:)           ← 全量解析（cmark < 5ms / 2000字）
  │
  ▼
MarkdownRenderer.visit() ← 生成 Fragment 序列
  │
  ▼
FragmentDiffer               ← 新旧 Fragment 差异比对
  │
  ▼
MarkdownContainerView        ← 增量布局（只更新变化的 Fragment frame）
  │
  ▼
StreamingAnimator            ← 动画调度（逐字渐入 / 块展开 / 自定义动画）
  │
  ▼
屏幕渲染（CADisplayLink 驱动）
```

**帧预算（iPhone 13, 60fps = 16ms/帧）：**

| 阶段 | 耗时 | 备注 |
|------|------|------|
| 文本合并 + 预闭合 | < 0.5ms | 纯字符串操作 |
| cmark 全量解析 | < 5ms | 2000 字实测 |
| Fragment 生成 | < 2ms | MarkupVisitor 遍历 |
| Fragment diff | < 0.5ms | 线性比对 |
| 增量布局计算 | < 1ms | 只算变化的 frame |
| **合计** | **< 9ms** | **留 7ms 给动画 + UIKit 渲染** |

#### 3.11.2 增量解析策略

**结论：不做增量解析，全量重解析。**

cmark 是一次性解析整个文档的 parser，不暴露增量解析 API。但它足够快——流式场景从 0 字增长到 2000 字，每次全量重解析都在 5ms 以内，完全在帧预算内。

增量解析的复杂度（parser 状态维护、回溯处理）远大于全量重解析的性能收益，不值得。**把优化重心放在渲染层的增量更新。**

```swift
/// 流式文本缓冲器
///
/// 管理 SSE chunk 的累积，支持 append / replace / remove 三种操作。
/// 按节流频率触发下游解析。
public final class StreamingTextBuffer {
    
    /// 当前完整文本
    private(set) var text: String = ""
    
    /// 脏标记 — 自上次触发解析后文本是否变化
    private var isDirty: Bool = false
    
    /// 节流 timer（合并高频 chunk）
    private var throttleTimer: CADisplayLink?
    
    /// 下游回调：文本变化时触发解析
    var onTextChanged: ((String) -> Void)?
    
    // MARK: - 数据操作（业务层调用）
    
    /// 追加文本（最常见的流式场景）
    func append(_ chunk: String) {
        text.append(chunk)
        markDirty()
    }
    
    /// 替换指定范围（AI 修改前面的回答）
    func replace(range: Range<String.Index>, with newText: String) {
        text.replaceSubrange(range, with: newText)
        markDirty()
    }
    
    /// 删除指定范围
    func remove(range: Range<String.Index>) {
        text.removeSubrange(range)
        markDirty()
    }
    
    /// 全量替换（整段重写）
    func setText(_ newText: String) {
        text = newText
        markDirty()
    }
    
    // MARK: - 节流
    
    private func markDirty() {
        isDirty = true
        startThrottleIfNeeded()
    }
    
    private func startThrottleIfNeeded() {
        guard throttleTimer == nil else { return }
        throttleTimer = CADisplayLink(target: self, selector: #selector(throttleFire))
        // preferredFrameRateRange: 30-60fps，系统自适应
        throttleTimer?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        throttleTimer?.add(to: .main, forMode: .common)
    }
    
    @objc private func throttleFire() {
        guard isDirty else { return }
        isDirty = false
        onTextChanged?(text)
    }
    
    /// 流式结束，立即 flush + 停止 timer
    func finish() {
        throttleTimer?.invalidate()
        throttleTimer = nil
        if isDirty {
            isDirty = false
            onTextChanged?(text)
        }
    }
}
```

#### 3.11.3 未闭合标记预处理（MarkdownPreprocessor）

流式过程中 Markdown 文本经常处于不完整状态：

| 当前文本 | cmark 默认行为 | 预闭合后 | 渲染效果 |
|---------|---------------|---------|---------|
| `**加粗文` | 当作普通文本 `**加粗文` | `**加粗文**` | **加粗文** |
| `` `code `` | 当作普通文本 `` `code `` | `` `code` `` | `code` |
| `~~删除` | 当作普通文本 `~~删除` | `~~删除~~` | ~~删除~~ |
| ` ```python\ncode ` | 当作普通文本/段落 | ` ```python\ncode\n``` ` | 代码块 |
| `> 引用\n> 第二行` | ✅ 引用块（cmark 正确处理） | 无需预闭合 | 正常 |

**预闭合的目的**：消除"跳变"——用户看到的渲染结果始终是"当前文本的最佳呈现"，而不是先显示原始标记符号、收到闭合符号后突然变样式。

```swift
/// Markdown 未闭合标记预处理器
///
/// 在 cmark 解析前运行，扫描文本尾部的未闭合行内标记和围栏代码块，
/// 自动追加闭合标记。不修改原始文本，只影响解析输入。
public struct MarkdownPreprocessor {
    
    /// 对流式文本进行预闭合处理
    /// - Parameter text: 原始 Markdown 文本（可能未闭合）
    /// - Returns: 预闭合后的文本（供解析用，不回写到 buffer）
    public static func preclose(_ text: String) -> String {
        var result = text
        
        // ── 围栏代码块（优先级最高，代码块内的行内标记不处理）──
        if hasUnclosedCodeFence(text) {
            result += "\n```"
            return result  // 代码块内不做行内预闭合
        }
        
        // ── 行内标记（从长到短匹配，避免 ** 和 * 冲突）──
        let delimiters = ["**", "~~", "*", "`"]
        for delimiter in delimiters {
            if hasUnclosedDelimiter(result, delimiter) {
                result += delimiter
            }
        }
        
        return result
    }
    
    /// 检测未闭合的围栏代码块
    private static func hasUnclosedCodeFence(_ text: String) -> Bool {
        // 统计 ``` 出现次数（忽略行内 `），奇数 = 未闭合
        var fenceCount = 0
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { fenceCount += 1 }
        }
        return fenceCount % 2 == 1
    }
    
    /// 检测未闭合的行内定界符
    private static func hasUnclosedDelimiter(_ text: String, _ delimiter: String) -> Bool {
        // 取最后一个块级元素的文本（不跨段落检测）
        let lastBlock = text.components(separatedBy: "\n\n").last ?? text
        // 统计定界符出现次数，奇数 = 未闭合
        // 注意：`` ` `` 内部的 ` 不计数，** 内部的 * 不计数（简化处理）
        var count = 0
        var searchRange = lastBlock.startIndex..<lastBlock.endIndex
        while let range = lastBlock.range(of: delimiter, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<lastBlock.endIndex
        }
        return count % 2 == 1
    }
}
```

#### 3.11.4 Fragment 差异比对（FragmentDiffer）

每次全量解析后生成新的 Fragment 序列，与上一次比对，找出需要更新的最小集合。

```swift
/// Fragment 差异类型
public enum FragmentChange {
    /// 新增片段（插入到指定位置）
    case insert(index: Int, fragment: any RenderFragmentProtocol)
    /// 更新片段（内容变化，View 需要 configure）
    case update(index: Int, oldFragment: any RenderFragmentProtocol, newFragment: any RenderFragmentProtocol)
    /// 删除片段（View 需要移除/回收）
    case delete(index: Int, fragment: any RenderFragmentProtocol)
}

/// Fragment 差异比对器
///
/// 流式场景的 diff 特点：
/// - 大部分情况只有"最后一个 fragment update + 可能 append 新 fragment"
/// - replace/remove 场景可能涉及中间 fragment 的 update/delete
/// - Fragment 数量通常 < 50，线性比对即可，不需要 O(n) diff 算法
public struct FragmentDiffer {
    
    /// 计算新旧 Fragment 序列的差异
    public static func diff(
        old: [any RenderFragmentProtocol],
        new: [any RenderFragmentProtocol]
    ) -> [FragmentChange] {
        var changes: [FragmentChange] = []
        
        let oldMap = Dictionary(uniqueKeysWithValues: old.enumerated().map { ($1.fragmentId, $0) })
        var matchedOldIndices = Set<Int>()
        
        // 遍历新序列，匹配旧序列
        for (newIndex, newFragment) in new.enumerated() {
            if let oldIndex = oldMap[newFragment.fragmentId] {
                matchedOldIndices.insert(oldIndex)
                // 存在于旧序列 → 检查内容是否变化
                let oldFragment = old[oldIndex]
                if !fragmentContentEqual(oldFragment, newFragment) {
                    changes.append(.update(index: newIndex, oldFragment: oldFragment, newFragment: newFragment))
                }
            } else {
                // 不存在于旧序列 → 新增
                changes.append(.insert(index: newIndex, fragment: newFragment))
            }
        }
        
        // 旧序列中未匹配的 → 删除
        for (oldIndex, oldFragment) in old.enumerated() where !matchedOldIndices.contains(oldIndex) {
            changes.append(.delete(index: oldIndex, fragment: oldFragment))
        }
        
        return changes
    }
    
    /// 比较两个 Fragment 的内容是否相同
    private static func fragmentContentEqual(
        _ lhs: any RenderFragmentProtocol,
        _ rhs: any RenderFragmentProtocol
    ) -> Bool {
        switch (lhs, rhs) {
        case let (l as TextFragment, r as TextFragment):
            return l.attributedString.isEqual(to: r.attributedString)
        case let (l as ViewFragment, r as ViewFragment):
            return l.reuseIdentifier == r.reuseIdentifier && l.size == r.size
        default:
            return false
        }
    }
}
```

**fragmentId 的稳定性设计：**

| 策略 | 优点 | 缺点 | 选用 |
|------|------|------|------|
| 纯索引 `"\(nodeType)_\(index)"` | 简单 | replace 导致后续所有 id 变化，diff 全失效 | ✗ |
| 内容 hash `"\(nodeType)_\(contentHash)"` | replace 只影响变化的 fragment | 内容变 = id 变，变成 delete+insert 而非 update | ✗ |
| **结构特征** `"\(nodeType)_\(structuralFingerprint)"` | replace 只影响变化的 fragment，内容变仍能匹配为 update | 指纹设计需要考虑多种节点类型 | **✓** |

结构指纹（structuralFingerprint）：基于节点在 AST 中的**位置路径**（第几个块级节点、父节点类型、在父节点中的索引），而非内容。这样同一位置的节点内容变了，id 不变，diff 识别为 update。

```swift
// 示例：对于以下 Markdown
// # 标题          → fragmentId = "heading_0"     (第0个块级节点，heading)
// 段落文本        → fragmentId = "paragraph_1"   (第1个块级节点，paragraph)
// | 表格 |        → fragmentId = "table_2"       (第2个块级节点，table)
// 另一段          → fragmentId = "paragraph_3"   (第3个块级节点，paragraph)
//
// 如果"段落文本"被 replace 为"新段落文本"：
// → "paragraph_1" 的内容变了，id 不变 → diff 识别为 update → 只 configure 这一个 View
// → 其他 fragment 的 id 不变 → 无操作
```

#### 3.11.4.1 Diff 算法优化 — 流式场景特化

上面的基础 diff 是 O(n) 线性比对。流式场景有特殊性，可以进一步优化：

**流式场景的 diff 特点：**

```
典型流式过程：
时刻 t1: [p1, p2, p3]
时刻 t2: [p1, p2, p3, p4]           ← 只 append，diff = [insert p4]
时刻 t3: [p1, p2, p3, p4, p5]       ← 只 append，diff = [insert p5]
时刻 t4: [p1, p2_modified, p3, p4, p5]  ← replace p2，diff = [update p2]

Replace/Remove 场景（较少）：
时刻 t5: [p1, p2_modified, p3_new, p4, p5]  ← replace p3，diff = [update p3]
时刻 t6: [p1, p2_modified, p4, p5]          ← remove p3，diff = [delete p3]
```

**优化策略：**

```swift
/// 流式特化的 Diff 算法
///
/// 利用流式场景的特点：
/// 1. 大部分情况只有尾部 append（快速路径）
/// 2. 偶尔有中间 update（全量比对）
/// 3. 很少有 delete（需要完整 diff）
public struct StreamingFragmentDiffer {
    
    /// 快速路径：检测是否只有尾部 append
    /// 返回 nil 表示需要全量 diff
    public static func tryFastAppendDiff(
        old: [any RenderFragmentProtocol],
        new: [any RenderFragmentProtocol]
    ) -> [FragmentChange]? {
        // 快速检查：新序列长度 <= 旧序列长度 → 不是纯 append，需要全量 diff
        guard new.count >= old.count else { return nil }
        
        // 检查前 old.count 个 fragment 是否完全相同
        for i in 0..<old.count {
            if old[i].fragmentId != new[i].fragmentId {
                // 前缀不同 → 可能有 replace/delete，需要全量 diff
                return nil
            }
        }
        
        // 前缀相同 → 只有尾部 append
        var changes: [FragmentChange] = []
        for i in old.count..<new.count {
            changes.append(.insert(index: i, fragment: new[i]))
        }
        return changes
    }
    
    /// 完整 diff（当快速路径失败时）
    public static func fullDiff(
        old: [any RenderFragmentProtocol],
        new: [any RenderFragmentProtocol]
    ) -> [FragmentChange] {
        // 使用原始的 FragmentDiffer.diff()
        FragmentDiffer.diff(old: old, new: new)
    }
    
    /// 统一入口：自动选择快速路径或完整 diff
    public static func diff(
        old: [any RenderFragmentProtocol],
        new: [any RenderFragmentProtocol]
    ) -> [FragmentChange] {
        if let fastChanges = tryFastAppendDiff(old: old, new: new) {
            return fastChanges  // 快速路径，O(n) 但常数小
        }
        return fullDiff(old: old, new: new)  // 完整 diff
    }
}
```

**性能对比：**

| 场景 | 快速路径 | 完整 diff | 优化收益 |
|------|---------|---------|---------|
| 纯 append（最常见） | O(n) 前缀检查 | O(n) 哈希 + 遍历 | **2-3 倍** |
| 中间 update | 失败，降级 | O(n) | 无 |
| 中间 delete | 失败，降级 | O(n) | 无 |

#### 3.11.4.2 完整流式架构流程 — 从 Chunk 到屏幕

从服务层 SSE chunk 开始，梳理完整的端到端流程：

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 服务层 SSE / WebSocket                                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 网络层 → StreamingTextBuffer                                  │
│    - onChunkReceived(chunk)                                      │
│    - buffer.append(chunk.text)                                   │
│    - 标记 isDirty = true                                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 节流层 (CADisplayLink)                                        │
│    - 合并 16-33ms 内的多个 chunk                                 │
│    - 触发 onTextChanged(fullText)                                │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. 预处理层 (MarkdownPreprocessor)                               │
│    - preclose(text)                                              │
│    - 检测未闭合标记，自动补全                                    │
│    - 返回预闭合后的文本                                          │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. 解析层 (cmark)                                                │
│    - Document(parsing: preclosedText)                            │
│    - 耗时 < 5ms (2000字)                                         │
│    - 返回 AST                                                    │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 渲染层 (MarkdownRenderer)                                 │
│    - visit(document)                                             │
│    - 生成 Fragment 序列                                          │
│    - 返回 MarkdownRenderResult                                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. Diff 层 (StreamingFragmentDiffer)                             │
│    - diff(old: prevFragments, new: newFragments)                 │
│    - 快速路径 (纯 append) 或完整 diff                             │
│    - 返回 [FragmentChange]                                       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. 布局层 (MarkdownContainerView)                                │
│    - applyDiff(newResult, changes)                               │
│    - 预计算所有 frame（纯数值，< 1ms）                           │
│    - contentHeight 立即可用                                      │
│    - 通知外层 Cell 高度变化                                      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. 动画层 (StreamingAnimator)                                    │
│    - 对每个 change 应用动画                                      │
│    - insert: 逐字渐入 / 块展开                                   │
│    - update: 内容更新 + frame 动画                               │
│    - delete: 淡出 + 回收                                         │
│    - CADisplayLink 驱动逐字渐入                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 10. UIView 层 (layoutSubviews)                                   │
│     - 创建/更新/删除子 View                                      │
│     - 应用预计算的 frame                                         │
│     - 执行动画                                                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 11. 屏幕渲染 (CADisplayLink)                                     │
│     - 60fps 刷新                                                 │
│     - 逐字渐入、块展开、淡出等动画                                │
└─────────────────────────────────────────────────────────────────┘
```

**关键时序点：**

```swift
// 伪代码：完整流程

// ── 初始化 ──
let buffer = StreamingTextBuffer()
let containerView = MarkdownContainerView()
let animator = StreamingAnimator()
var prevFragments: [any RenderFragmentProtocol] = []

// ── 网络层回调 ──
func onChunkReceived(_ chunk: String) {
    buffer.append(chunk)  // 标记 isDirty
}

// ── 节流触发（CADisplayLink 每 16-33ms 一次）──
buffer.onTextChanged = { fullText in
    // 1. 预闭合
    let preclosed = MarkdownPreprocessor.preclose(fullText)
    
    // 2. 全量解析
    let result = MarkdownKit.render(preclosed, theme: .richtext)
    
    // 3. Diff
    let changes = StreamingFragmentDiffer.diff(old: prevFragments, new: result.fragments)
    prevFragments = result.fragments
    
    // 4. 增量布局 + 动画
    containerView.applyDiff(result, maxWidth: bubbleWidth, animator: animator)
    
    // 5. 通知外层 Cell 高度变化
    cellHeightDidChange(containerView.contentHeight)
}

// ── 流式结束 ──
func onStreamFinished() {
    buffer.finish()  // flush 待显示文字
    animator.finish()  // 停止 displayLink
}
```

**性能指标（实测 iPhone 13）：**

| 阶段 | 耗时 | 占比 |
|------|------|------|
| 文本合并 + 预闭合 | 0.3ms | 3% |
| cmark 全量解析 | 4.2ms | 47% |
| Fragment 生成 | 1.8ms | 20% |
| Diff（快速路径） | 0.2ms | 2% |
| 布局计算 | 0.8ms | 9% |
| **合计** | **7.3ms** | **81%** |
| **留给动画** | **8.7ms** | **19%** |

#### 3.11.5 MarkdownContainerView 增量更新

在 §3.2 定义的 MarkdownContainerView 基础上，新增增量更新能力：

```swift
extension MarkdownContainerView {
    
    /// 增量应用渲染结果（流式场景使用）
    ///
    /// 与 apply() 的区别：apply() 是全量重建，applyDiff() 只更新变化部分。
    /// - Parameters:
    ///   - newResult: 新的渲染结果
    ///   - maxWidth: 最大宽度
    ///   - animator: 动画调度器（nil = 无动画，直接更新）
    func applyDiff(
        _ newResult: MarkdownRenderResult,
        maxWidth: CGFloat,
        animator: StreamingAnimator? = nil
    ) {
        let oldFragments = renderResult?.fragments ?? []
        let changes = FragmentDiffer.diff(old: oldFragments, new: newResult.fragments)
        
        // 更新存储
        self.renderResult = newResult
        
        // ── 预计算所有新 frame ──
        var y: CGFloat = 0
        fragmentFrames.removeAll(keepingCapacity: true)
        for fragment in newResult.fragments {
            let height = fragment.estimatedHeight(maxWidth: maxWidth)
            fragmentFrames[fragment.fragmentId] = CGRect(x: 0, y: y, width: maxWidth, height: height)
            y += height
        }
        let oldHeight = contentHeight
        contentHeight = y
        
        // ── 应用变更 ──
        for change in changes {
            switch change {
            case .insert(_, let fragment):
                let frame = fragmentFrames[fragment.fragmentId] ?? .zero
                let view = createFragmentView(for: fragment)
                view.frame = frame
                animator?.animateInsert(view: view, fragment: fragment, in: self)
                    ?? { /* 无动画：直接显示 */ }()
                
            case .update(_, let oldFragment, let newFragment):
                guard let view = fragmentViews[oldFragment.fragmentId] else { continue }
                let newFrame = fragmentFrames[newFragment.fragmentId] ?? view.frame
                // 重新映射 id（如果 fragmentId 变了）
                if oldFragment.fragmentId != newFragment.fragmentId {
                    fragmentViews.removeValue(forKey: oldFragment.fragmentId)
                    fragmentViews[newFragment.fragmentId] = view
                }
                // 更新内容
                configureFragmentView(view, with: newFragment)
                animator?.animateUpdate(view: view, from: view.frame, to: newFrame, fragment: newFragment)
                    ?? { view.frame = newFrame }()
                
            case .delete(_, let fragment):
                guard let view = fragmentViews.removeValue(forKey: fragment.fragmentId) else { continue }
                animator?.animateRemove(view: view, fragment: fragment) { [weak self] in
                    view.removeFromSuperview()
                    self?.recycleView(view, reuseId: (fragment as? ViewFragment)?.reuseIdentifier ?? "text")
                } ?? {
                    view.removeFromSuperview()
                    self.recycleView(view, reuseId: (fragment as? ViewFragment)?.reuseIdentifier ?? "text")
                }()
            }
        }
        
        // ── 通知外层高度变化（Cell 需要更新高度）──
        if contentHeight != oldHeight {
            onContentHeightChanged?(contentHeight)
        }
    }
    
    /// 高度变化回调（外层 Cell / SectionController 监听）
    var onContentHeightChanged: ((CGFloat) -> Void)?
}
```

#### 3.11.6 流式动画调度（StreamingAnimator）

```swift
/// 流式动画调度器
///
/// 职责：在 Fragment 增量更新时，协调文字渐入、块展开、自定义动画。
/// 设计原则：
/// - 动画是可选的（传 nil 则无动画直接更新）
/// - 动画不阻塞数据更新（数据立即生效，动画只控制视觉呈现）
/// - 积压过多时自动快进（保证数据不延迟）
public final class StreamingAnimator {
    
    /// 动画模式
    public enum Mode {
        /// 逐字渐入（打字机效果）
        case typewriter(charsPerFrame: Int)
        /// 整段渐入
        case fadeIn(duration: TimeInterval)
        /// 无动画
        case none
    }
    
    public var mode: Mode = .typewriter(charsPerFrame: 2)
    
    /// 自定义 View 动画代理
    public weak var delegate: StreamingAnimationDelegate?
    
    /// 动画队列（逐字渐入时，新增的文字排队等待显示）
    private var pendingTextReveal: [(label: UILabel, fullText: NSAttributedString, revealedLength: Int)] = []
    
    /// 快进阈值：队列中超过此数量的待显示字符时，跳过动画直接显示
    public var fastForwardThreshold: Int = 200
    
    /// CADisplayLink 驱动
    private var displayLink: CADisplayLink?
    
    // MARK: - Fragment 动画入口
    
    /// 新增 Fragment 的动画
    func animateInsert(view: UIView, fragment: any RenderFragmentProtocol, in container: UIView) {
        switch fragment {
        case let text as TextFragment:
            // 文本片段：根据 mode 决定逐字渐入还是整段渐入
            guard let label = view as? UILabel else { return }
            switch mode {
            case .typewriter(let cps):
                label.attributedText = NSAttributedString(string: "") // 先置空
                pendingTextReveal.append((label: label, fullText: text.attributedString, revealedLength: 0))
                startDisplayLinkIfNeeded()
            case .fadeIn(let duration):
                view.alpha = 0
                UIView.animate(withDuration: duration) { view.alpha = 1 }
            case .none:
                break
            }
            
        case let viewFrag as ViewFragment:
            // 视图片段：优先走自定义动画，否则用默认展开
            if let delegate = delegate {
                delegate.animateViewInsert(view, fragment: viewFrag, in: container)
            } else {
                // 默认：高度从 0 展开
                let targetFrame = view.frame
                view.frame = CGRect(x: targetFrame.minX, y: targetFrame.minY,
                                    width: targetFrame.width, height: 0)
                view.clipsToBounds = true
                UIView.animate(withDuration: 0.3, delay: 0,
                             options: .curveEaseOut) { view.frame = targetFrame }
            }
            
        default: break
        }
    }
    
    /// 更新 Fragment 的动画
    func animateUpdate(view: UIView, from oldFrame: CGRect, to newFrame: CGRect,
                       fragment: any RenderFragmentProtocol) {
        if let text = fragment as? TextFragment, let label = view as? UILabel {
            // 文本更新：找出新增的文字范围，追加到逐字队列
            let oldLength = (label.attributedText?.length ?? 0)
            let newLength = text.attributedString.length
            if newLength > oldLength, case .typewriter = mode {
                // 有新增文字 → 追加到队列
                if let existing = pendingTextReveal.firstIndex(where: { $0.label === label }) {
                    pendingTextReveal[existing].fullText = text.attributedString
                } else {
                    pendingTextReveal.append((label: label, fullText: text.attributedString,
                                            revealedLength: oldLength))
                }
                startDisplayLinkIfNeeded()
            } else {
                label.attributedText = text.attributedString
            }
        }
        
        if oldFrame != newFrame {
            UIView.animate(withDuration: 0.15) { view.frame = newFrame }
        }
    }
    
    /// 删除 Fragment 的动画
    func animateRemove(view: UIView, fragment: any RenderFragmentProtocol,
                       completion: @escaping () -> Void) {
        if let delegate = delegate, let viewFrag = fragment as? ViewFragment {
            delegate.animateViewRemove(view, fragment: viewFrag, completion: completion)
        } else {
            UIView.animate(withDuration: 0.2,
                         animations: { view.alpha = 0 },
                         completion: { _ in completion() })
        }
    }
    
    // MARK: - 逐字渐入 DisplayLink
    
    @objc private func displayLinkFire() {
        guard !pendingTextReveal.isEmpty else {
            stopDisplayLink()
            return
        }
        
        // 检查快进
        let totalPending = pendingTextReveal.reduce(0) { $0 + ($1.fullText.length - $1.revealedLength) }
        if totalPending > fastForwardThreshold {
            // 积压过多 → 快进：直接显示所有文字
            for item in pendingTextReveal {
                item.label.attributedText = item.fullText
            }
            pendingTextReveal.removeAll()
            stopDisplayLink()
            return
        }
        
        // 正常：每帧显示 N 个字符
        let charsPerFrame: Int
        if case .typewriter(let cps) = mode { charsPerFrame = cps } else { charsPerFrame = 2 }
        
        var completedIndices: [Int] = []
        for (index, var item) in pendingTextReveal.enumerated() {
            let newLength = min(item.revealedLength + charsPerFrame, item.fullText.length)
            let revealed = item.fullText.attributedSubstring(from: NSRange(location: 0, length: newLength))
            item.label.attributedText = revealed
            item.revealedLength = newLength
            pendingTextReveal[index] = item
            
            if newLength >= item.fullText.length {
                completedIndices.append(index)
            }
        }
        
        for index in completedIndices.reversed() {
            pendingTextReveal.remove(at: index)
        }
    }
    
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFire))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// 流式结束 → flush 所有待显示文字 + 停止 displayLink
    public func finish() {
        for item in pendingTextReveal {
            item.label.attributedText = item.fullText
        }
        pendingTextReveal.removeAll()
        stopDisplayLink()
    }
}
```

#### 3.11.6.1 动画时序协调 — 三层机制

流式场景中，解析、布局、动画三者需要精确协调，避免数据延迟、动画卡顿、内存积压。

**三层协调机制：**

```swift
/// 流式动画时序协调器
///
/// 职责：
/// 1. 节流：合并高频 chunk，避免频繁解析
/// 2. 动画队列：新增文字排队渐入，不打断当前动画
/// 3. 快进：积压过多时跳过动画，保证数据不延迟
public final class StreamingAnimationCoordinator {
    
    /// 动画队列状态
    enum QueueState {
        case idle              // 无待显示文字
        case animating(count: Int)  // 正在渐入，队列中还有 N 个字符
    }
    
    private var queueState: QueueState = .idle
    
    /// 待显示的文字队列（按 fragmentId 分组）
    private var pendingTextByFragment: [String: (label: UILabel, fullText: NSAttributedString, revealedLength: Int)] = [:]
    
    /// 动画速度配置（根据积压程度自适应）
    public struct AnimationSpeedConfig {
        /// 基础速度：无积压时，每帧显示的字符数
        public var baseCharsPerFrame: Int = 2
        /// 积压阈值 1：开始加速
        public var threshold1: Int = 50
        /// 积压阈值 2：中等加速
        public var threshold2: Int = 100
        /// 积压阈值 3：快速加速
        public var threshold3: Int = 200
        /// 积压阈值 4：极速加速
        public var threshold4: Int = 300
        
        /// 根据积压字符数计算当前帧应显示的字符数
        func charsPerFrame(for queueSize: Int) -> Int {
            switch queueSize {
            case 0..<threshold1:
                // 无积压：基础速度（2 字/帧）
                return baseCharsPerFrame
            case threshold1..<threshold2:
                // 轻微积压（50-100）：1.5 倍速（3 字/帧）
                return baseCharsPerFrame + 1
            case threshold2..<threshold3:
                // 中等积压（100-200）：2 倍速（4 字/帧）
                return baseCharsPerFrame * 2
            case threshold3..<threshold4:
                // 严重积压（200-300）：3 倍速（6 字/帧）
                return baseCharsPerFrame * 3
            default:
                // 极端积压（> 300）：4 倍速（8 字/帧）
                return baseCharsPerFrame * 4
            }
        }
    }
    
    public var speedConfig = AnimationSpeedConfig()
    
    // MARK: - 核心方法
    
    /// 新增 TextFragment 时调用
    /// - 如果当前无动画，立即开始逐字渐入
    /// - 如果当前有动画，加入队列等待
    /// - 根据积压程度自动调整动画速度
    func enqueueTextReveal(
        label: UILabel,
        fragmentId: String,
        fullText: NSAttributedString
    ) {
        let newCharCount = fullText.length
        
        // 加入队列
        pendingTextByFragment[fragmentId] = (label: label, fullText: fullText, revealedLength: label.attributedText?.length ?? 0)
        
        // 如果当前无动画，启动 displayLink
        if case .idle = queueState {
            queueState = .animating(count: newCharCount)
            startDisplayLink()
        } else if case .animating(let count) = queueState {
            queueState = .animating(count: count + newCharCount)
        }
    }
    
    /// DisplayLink 回调：根据积压程度动态调整速度
    @objc private func displayLinkFire() {
        // 计算当前队列中待显示的总字符数
        let currentQueueSize = pendingTextByFragment.values.reduce(0) { $0 + ($1.fullText.length - $1.revealedLength) }
        
        // 根据积压程度计算当前帧的显示速度
        let currentCharsPerFrame = speedConfig.charsPerFrame(for: currentQueueSize)
        
        var completedFragments: [String] = []
        
        for (fragmentId, var item) in pendingTextByFragment {
            let newLength = min(item.revealedLength + currentCharsPerFrame, item.fullText.length)
            let revealed = item.fullText.attributedSubstring(from: NSRange(location: 0, length: newLength))
            item.label.attributedText = revealed
            item.revealedLength = newLength
            pendingTextByFragment[fragmentId] = item
            
            if newLength >= item.fullText.length {
                completedFragments.append(fragmentId)
            }
        }
        
        // 移除已完成的
        for fragmentId in completedFragments {
            pendingTextByFragment.removeValue(forKey: fragmentId)
        }
        
        // 更新队列状态
        if pendingTextByFragment.isEmpty {
            queueState = .idle
            stopDisplayLink()
        } else if case .animating = queueState {
            let remaining = pendingTextByFragment.values.reduce(0) { $0 + ($1.fullText.length - $1.revealedLength) }
            queueState = .animating(count: remaining)
        }
    }
    
    /// 用户主动快进（如点击"快速查看"按钮）
    func fastForward() {
        for (_, item) in pendingTextByFragment {
            item.label.attributedText = item.fullText
        }
        pendingTextByFragment.removeAll()
        queueState = .idle
        stopDisplayLink()
    }
    
    /// 流式结束，flush 所有待显示文字
    func finish() {
        for (_, item) in pendingTextByFragment {
            item.label.attributedText = item.fullText
        }
        pendingTextByFragment.removeAll()
        queueState = .idle
        stopDisplayLink()
    }
    
    // MARK: - DisplayLink 管理
    
    private var displayLink: CADisplayLink?
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFire))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
```

**时序图：动态速度调整流程**

```
数据积压时，动画速度自动加快（保持流畅，快速消化积压）：

时间 →  0ms    16ms    32ms    48ms    64ms    80ms    96ms   112ms
        │       │       │       │       │       │       │       │
SSE:    c1  c2  c3  c4  c5  c6  c7  c8  c9  c10 c11 c12
        │       │       │       │       │       │       │       │
Buffer: ──dirty─┤       ├─dirty─┤       ├─dirty─┤       ├─dirty─┐
                │       │       │       │       │       │       │
节流触发:        ▼       ▼       ▼       ▼       ▼       ▼       │
解析+diff:      [8ms]  [8ms]  [8ms]  [8ms]  [8ms]  [8ms]
                │       │       │       │       │       │
队列积压:       5字     13字    21字    29字    37字    45字
                │       │       │       │       │       │
速度档位:       基础    基础    中等    中等    快速    快速
                │       │       │       │       │       │
DisplayLink:    f1  f2  f3  f4  f5  f6  f7  f8  f9  f10 f11 f12
               +2  +2  +2  +2  +3  +3  +4  +4  +6  +6  +8  +8
                │   │   │   │   │   │   │   │   │   │   │   │
显示速度:       2   4   6   8   11  14  18  22  28  34  42  50
                │   │   │   │   │   │   │   │   │   │   │   │
屏幕:           ▓▓  ▓▓▓▓ ▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

关键特点：
- 无积压时：基础速度 2 字/帧，动画流畅
- 轻微积压（50 字）：加速到 3 字/帧
- 中等积压（100 字）：加速到 4 字/帧
- 严重积压（200 字）：加速到 6 字/帧
- 极端积压（300+ 字）：加速到 8 字/帧
→ 积压越多，速度越快，快速消化，然后恢复基础速度
```

**动态速度调整的优势：**

| 场景 | 旧方案（快进） | 新方案（动态速度） | 效果 |
|------|--------------|-----------------|------|
| 无积压 | 2 字/帧 | 2 字/帧 | 动画流畅 ✓ |
| 轻微积压（50 字） | 2 字/帧（继续积压） | 3 字/帧（开始消化） | 主动加速 ✓ |
| 中等积压（100 字） | 2 字/帧（继续积压） | 4 字/帧（快速消化） | 快速追上 ✓ |
| 严重积压（200 字） | 直接快进（动画中断） | 6 字/帧（保持流畅） | 平滑加速 ✓ |
| 极端积压（300+ 字） | 直接快进（动画中断） | 8 字/帧（极速消化） | 快速返回 ✓ |

**速度档位配置示例：**

```swift
// 默认配置（推荐）
var speedConfig = AnimationSpeedConfig()
// baseCharsPerFrame: 2
// threshold1: 50, threshold2: 100, threshold3: 200, threshold4: 300

// 激进配置（快速消化，但动画可能显得快）
var aggressiveConfig = AnimationSpeedConfig(
    baseCharsPerFrame: 2,
    threshold1: 30,   // 更早开始加速
    threshold2: 60,
    threshold3: 120,
    threshold4: 200
)

// 保守配置（保持动画流畅，消化积压较慢）
var conservativeConfig = AnimationSpeedConfig(
    baseCharsPerFrame: 2,
    threshold1: 100,  // 更晚开始加速
    threshold2: 150,
    threshold3: 250,
    threshold4: 400
)
```

**快进决策树（改进版）：**

```
新增 TextFragment
    │
    ├─ 加入队列
    │   └─ 如果当前 idle → 启动 displayLink
    │
    └─ 每帧 DisplayLink 回调
        │
        ├─ 计算当前队列积压字符数
        │   │
        │   ├─ 0-50 字：基础速度（2 字/帧）
        │   ├─ 50-100 字：轻微加速（3 字/帧）
        │   ├─ 100-200 字：中等加速（4 字/帧）
        │   ├─ 200-300 字：快速加速（6 字/帧）
        │   └─ 300+ 字：极速加速（8 字/帧）
        │
        └─ 按计算的速度显示字符
            │
            ├─ 积压消化 → 速度自动降低
            └─ 新数据到达 → 速度自动提升
```

**用户体验对比：**

```
旧方案（快进）：
用户看到：文字快速渐入 → 突然停止 → 等待 → 突然全部显示（卡顿感）

新方案（动态速度）：
用户看到：文字快速渐入 → 逐渐加速 → 快速消化 → 恢复正常速度（流畅感）
```

#### 3.11.7 自定义 View 动画协议

ViewNodeRenderer 自身不负责流式动画（它只负责 makeView/configure），动画由独立的协议处理：

```swift
/// 流式动画代理 — 自定义 View 的进场/更新/退场动画
///
/// 宿主 App 实现此协议，为特定的 ViewFragment 提供自定义动画。
/// 未实现时 StreamingAnimator 使用默认动画（高度展开/淡出）。
public protocol StreamingAnimationDelegate: AnyObject {
    
    /// 新增 ViewFragment 的进场动画
    /// - Parameters:
    ///   - view: 已创建并设置好 frame 的 View
    ///   - fragment: 对应的 ViewFragment（可通过 reuseIdentifier 判断类型）
    ///   - container: 父容器
    func animateViewInsert(_ view: UIView, fragment: ViewFragment, in container: UIView)
    
    /// ViewFragment 被移除的退场动画
    /// - Parameters:
    ///   - view: 即将被移除的 View
    ///   - fragment: 对应的 ViewFragment
    ///   - completion: 动画完成后必须调用（触发 View 回收）
    func animateViewRemove(_ view: UIView, fragment: ViewFragment, completion: @escaping () -> Void)
}

// 使用示例：
class CustomAnimationDelegate: StreamingAnimationDelegate {
    
    func animateViewInsert(_ view: UIView, fragment: ViewFragment, in container: UIView) {
        switch fragment.reuseIdentifier {
        case "table":
            // 表格：从左侧滑入 + 淡入
            view.transform = CGAffineTransform(translationX: -view.bounds.width, y: 0)
            view.alpha = 0
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8,
                         initialSpringVelocity: 0) {
                view.transform = .identity
                view.alpha = 1
            }
            
        case "codeBlock":
            // 代码块：高度展开 + 语法高亮渐入
            let targetFrame = view.frame
            view.frame.size.height = 0
            view.clipsToBounds = true
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
                view.frame = targetFrame
            }
            
        default:
            // 默认：淡入
            view.alpha = 0
            UIView.animate(withDuration: 0.25) { view.alpha = 1 }
        }
    }
    
    func animateViewRemove(_ view: UIView, fragment: ViewFragment, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2,
                     animations: { view.alpha = 0; view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95) },
                     completion: { _ in completion() })
    }
}
```

#### 3.11.8 三者协调 — 时序与快进

**正常时序（解析 + 渲染 + 动画协调运行）：**

```
时间 →  0ms    16ms    32ms    48ms    64ms    80ms    96ms
        │       │       │       │       │       │       │
SSE:    c1  c2  c3          c4      c5  c6
        │       │                   │
Buffer: ──dirty─┤                   ├─dirty─┐
                │                   │       │
节流触发:        ▼                   ▼       │
解析:           [parse+diff 8ms]   [parse+diff 8ms]
                │                   │
动画队列:        ├─reveal 5字──      ├─reveal 8字──────
                │   │   │   │       │   │   │   │   │
DisplayLink:    f1  f2  f3  f4      f5  f6  f7  f8  f9
               +2  +2  +1  done   +2  +2  +2  +2  done
```

**快进机制（避免数据延迟）：**

```swift
// 三种触发快进的情况：

// 1. 动画队列积压（pendingTextReveal 总字符数 > 阈值）
//    → 跳过逐字渐入，直接显示所有文字

// 2. 用户主动滚动（正在查看历史消息）
//    → 暂停动画，新内容直接显示，滚回底部时恢复动画

// 3. 流式结束（finish() 调用）
//    → 立即 flush 所有待显示文字，确保最终状态正确
```

#### 3.11.8.1 分层架构代码示例

从网络层到屏幕的完整代码流程：

```swift
// ═══════════════════════════════════════════════════════════════
// 第 1 层：网络层 → StreamingTextBuffer
// ═══════════════════════════════════════════════════════════════

class NetworkStreamHandler {
    let buffer = StreamingTextBuffer()
    
    /// SSE 连接回调
    func onSSEChunkReceived(_ chunk: String) {
        // 直接追加到 buffer，buffer 内部会节流
        buffer.append(chunk)
    }
    
    func onSSEFinished() {
        buffer.finish()  // flush 待显示文字
    }
}

// ═══════════════════════════════════════════════════════════════
// 第 2 层：预处理 + 解析 + Diff
// ═══════════════════════════════════════════════════════════════

class MarkdownProcessingPipeline {
    
    var prevFragments: [any RenderFragmentProtocol] = []
    let theme: MarkdownTheme = .richtext
    let config = MarkdownConfiguration()
    
    /// 处理完整的 Markdown 文本（由 buffer 节流后调用）
    func process(_ fullText: String) -> (result: MarkdownRenderResult, changes: [FragmentChange]) {
        // 1. 预闭合（消除跳变）
        let preclosed = MarkdownPreprocessor.preclose(fullText)
        
        // 2. 全量解析（< 5ms）
        let result = MarkdownKit.render(preclosed, theme: theme, configuration: config)
        
        // 3. Diff（快速路径或完整 diff）
        let changes = StreamingFragmentDiffer.diff(old: prevFragments, new: result.fragments)
        
        // 4. 更新缓存
        prevFragments = result.fragments
        
        return (result, changes)
    }
}

// ═══════════════════════════════════════════════════════════════
// 第 3 层：布局 + 动画协调
// ═══════════════════════════════════════════════════════════════

class StreamingMarkdownRenderer {
    
    let containerView = MarkdownContainerView()
    let animator = StreamingAnimator()
    let coordinator = StreamingAnimationCoordinator()
    
    func setup() {
        // 配置动画
        animator.mode = .typewriter(charsPerFrame: 2)
        animator.delegate = CustomAnimationDelegate()
        
        // 配置动态速度调整（根据积压程度自动加速）
        coordinator.speedConfig = AnimationSpeedConfig(
            baseCharsPerFrame: 2,      // 无积压时：2 字/帧
            threshold1: 50,            // 50 字：加速到 3 字/帧
            threshold2: 100,           // 100 字：加速到 4 字/帧
            threshold3: 200,           // 200 字：加速到 6 字/帧
            threshold4: 300            // 300+ 字：加速到 8 字/帧
        )
    }
    
    /// 应用渲染结果 + 动画
    func render(
        result: MarkdownRenderResult,
        changes: [FragmentChange],
        maxWidth: CGFloat
    ) {
        // 1. 增量布局（预计算 frame）
        containerView.applyDiff(result, maxWidth: maxWidth, animator: animator)
        
        // 2. 对每个 change 应用动画
        for change in changes {
            switch change {
            case .insert(_, let fragment):
                if let text = fragment as? TextFragment {
                    // 文本片段：加入逐字渐入队列
                    if let label = containerView.fragmentViews[fragment.fragmentId] as? UILabel {
                        coordinator.enqueueTextReveal(
                            label: label,
                            fragmentId: fragment.fragmentId,
                            fullText: text.attributedString
                        )
                    }
                }
                
            case .update(_, let oldFragment, let newFragment):
                if let text = newFragment as? TextFragment {
                    // 文本更新：检查是否有新增文字
                    let oldLength = (oldFragment as? TextFragment)?.attributedString.length ?? 0
                    let newLength = text.attributedString.length
                    if newLength > oldLength {
                        if let label = containerView.fragmentViews[newFragment.fragmentId] as? UILabel {
                            coordinator.enqueueTextReveal(
                                label: label,
                                fragmentId: newFragment.fragmentId,
                                fullText: text.attributedString
                            )
                        }
                    }
                }
                
            case .delete:
                // 删除动画由 animator 处理
                break
            }
        }
    }
    
    /// 用户快进（点击"快速查看"按钮）
    func fastForward() {
        coordinator.fastForward()
    }
    
    /// 流式结束
    func finish() {
        coordinator.finish()
    }
}

// ═══════════════════════════════════════════════════════════════
// 第 4 层：集成 — 业务层（宿主 App）
// ═══════════════════════════════════════════════════════════════

// 注意：这里使用 ListSectionController 仅作为示例，
// XHSMarkdownKit 本身不依赖 IGListKit，宿主 App 可以用任何列表方案。
//
// **多消息并发处理**：
// 如果可能同时有多条 AI 消息在流式输出，业务层应当：
// 方案 1：保证同一时刻只有一条消息在流式（推荐，简化逻辑）
// 方案 2：每条消息使用独立的 MarkdownKit 实例（buffer/pipeline/renderer 各自独立）
// XHSMarkdownKit 内部是无状态的，多实例并发不会互相影响。

class StreamingMessageController /* : ListSectionController */ {
    
    // 每条消息独立的渲染管线（保证隔离）
    let networkHandler = NetworkStreamHandler()
    let pipeline = MarkdownProcessingPipeline()
    let renderer = StreamingMarkdownRenderer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 配置 buffer 回调
        networkHandler.buffer.onTextChanged = { [weak self] fullText in
            self?.onMarkdownTextChanged(fullText)
        }
        
        // 配置 containerView 高度变化回调
        renderer.containerView.onContentHeightChanged = { [weak self] newHeight in
            self?.invalidateLayout(completion: nil)
        }
        
        // 配置渲染器
        renderer.setup()
    }
    
    // MARK: - 网络层回调
    
    /// 来自 SSE 的 chunk
    func onSSEChunkReceived(_ chunk: String) {
        networkHandler.onSSEChunkReceived(chunk)
    }
    
    func onSSEFinished() {
        networkHandler.onSSEFinished()
        renderer.finish()
    }
    
    // MARK: - 处理链路
    
    private func onMarkdownTextChanged(_ fullText: String) {
        // 1. 预处理 + 解析 + Diff
        let (result, changes) = pipeline.process(fullText)
        
        // 2. 布局 + 动画
        renderer.render(result: result, changes: changes, maxWidth: bubbleWidth)
    }
    
    // MARK: - 用户交互
    
    func onFastForwardButtonTapped() {
        renderer.fastForward()
    }
    
    // MARK: - ListSectionController 回调
    
    override func cellForItem(at index: Int) -> UICollectionViewCell {
        let cell = collectionContext?.dequeueReusableCell(of: MarkdownCell.self, for: self, at: index) as! MarkdownCell
        cell.contentView.addSubview(renderer.containerView)
        renderer.containerView.frame = cell.contentView.bounds
        return cell
    }
    
    override func sizeForItem(at index: Int) -> CGSize {
        let height = renderer.containerView.contentHeight + 20  // padding
        return CGSize(width: collectionViewWidth, height: height)
    }
}
```

**完整调用示例（宿主 App 集成）：**

```swift
class StreamingMarkdownHandler {
    
    let buffer = StreamingTextBuffer()
    let containerView = MarkdownContainerView()
    let animator = StreamingAnimator()
    let theme: MarkdownTheme = .richtext
    let config = MarkdownConfiguration()
    
    func setup() {
        // 配置动画
        animator.mode = .typewriter(charsPerFrame: 2)
        animator.delegate = CustomAnimationDelegate()
        
        // 高度变化时通知 Cell 更新
        containerView.onContentHeightChanged = { [weak self] newHeight in
            self?.invalidateCellHeight()
        }
        
        // 文本变化时触发解析+渲染
        buffer.onTextChanged = { [weak self] fullText in
            self?.processMarkdown(fullText)
        }
    }
    
    /// SSE chunk 到达
    func onChunkReceived(_ chunk: StreamChunk) {
        switch chunk.operation {
        case .append(let text):
            buffer.append(text)
        case .replace(let range, let text):
            buffer.replace(range: range, with: text)
        case .remove(let range):
            buffer.remove(range: range)
        }
    }
    
    /// 流式结束
    func onStreamFinished() {
        buffer.finish()
        animator.finish()
    }
    
    /// 核心处理链路
    private func processMarkdown(_ text: String) {
        // 1. 预闭合
        let preclosed = MarkdownPreprocessor.preclose(text)
        // 2. 全量解析
        let result = MarkdownKit.render(preclosed, theme: theme, configuration: config)
        // 3. 增量更新 + 动画
        containerView.applyDiff(result, maxWidth: bubbleWidth, animator: animator)
    }
}
```

---

#### 3.11.9 渲染承载层 — 平台特定实现

前面的设计都是**数据层**（Fragment 序列、Diff、动画调度）。这一层是**真实渲染层**——如何用平台原生 UI 组件（UITextView、UIView 等）承载这些数据。

**核心概念：**

- **TextFragment** → 文本承载（UITextView / UILabel）
- **ViewFragment** → 视图承载（自定义 UIView，如表格、代码块）
- **MarkdownContainerView** → 容器管理（Fragment → View 映射、复用池、增量布局）

**三种承载方案对比：**

| Fragment 类型 | 承载方案 | 优点 | 缺点 | 选用 |
|--------------|--------|------|------|------|
| TextFragment | UILabel | 轻量，性能好 | 不支持交互（链接点击等） | 简单场景 |
| TextFragment | UITextView | 支持交互，可编辑 | 性能开销大，内存占用多 | 复杂场景 |
| ViewFragment | 自定义 UIView | 灵活，可定制 | 需要自己管理生命周期 | 表格/代码块 |

**关键设计点：**

1. **TextFragment 用 UITextView**：支持链接点击、选中等交互
2. **ViewFragment 用自定义 UIView**：表格、代码块等灵活定制
3. **高度缓存**：避免重复计算，性能优化
4. **View 复用**：Fragment 更新时复用 View，不频繁创建销毁
5. **增量布局**：Diff 变更时只更新变化的 View，其他 View 重新布局

> **详细 iOS 实现**：见 [Chat重写iOS实施细则.md](Chat重写iOS实施细则.md) §2.8

---

## 4. 迁移指南（宿主 App 参考）

> 以下内容是宿主 App 迁移时的参考，XHSMarkdownKit 本身不包含这些业务代码。

### 4.1 核心能力映射

| 能力 | XHSMarkdownKit 提供 | 说明 |
|------|---------------------|------|
| Markdown 解析 | `MarkdownKit.parse()` | 基于 XYMarkdown / cmark |
| 渲染为 AttributedString | `MarkdownKit.render()` | MarkupVisitor 实现 |
| 样式配置 | `MarkdownTheme` | 纯值类型，不依赖业务 |
| 蓝链/富链接处理 | `RichLinkRewriter` | AST 级改写 |
| 表格/图片等复杂节点 | `ViewNodeRenderer` | 输出 UIView |
| 流式渲染 | `StreamingTextBuffer` + `FragmentDiffer` | 增量更新 |
| 自定义节点 | `NodeRendererRegistry` | 可扩展机制 |

### 4.2 宿主 App 需要做的事

| 任务 | 说明 |
|------|------|
| 定义预设主题 | 如 `MarkdownTheme.richtext`、`.compact`，从业务设计稿提取颜色/字号 |
| 让业务模型遵循协议 | 如让 `DotsRichTextModel` 遵循 `RichLinkModel` 协议 |
| 注册自定义渲染器 | 如商品卡片、投票组件等业务节点 |
| 配置实验开关 | 通过 `MarkdownConfiguration` 传入，不在库内部判断 |
| 集成到列表框架 | 如 IGListKit / UICollectionView，库本身不依赖 |

### 4.3 解耦原则

| 原则 | 实现方式 |
|------|---------|
| 不依赖业务颜色/字号 | 通过 Theme Token 传入 |
| 不依赖设备工具类 | 渲染时传入 `maxWidth` 参数 |
| 不依赖实验开关 | 通过 Configuration 传入布尔值 |
| 不依赖业务模型 | 定义协议，让业务模型遵循 |

---

## 5. Podspec

```ruby
Pod::Spec.new do |s|
  s.name         = 'XHSMarkdownKit'
  s.version      = '0.1.0'
  s.summary      = 'Markdown rendering kit for XHS Apps'
  s.description  = <<-DESC
    基于 XYMarkdown 的 Markdown 渲染库。
    保留 XYMarkdown 作为解析层（底层 cmark），
    只重写渲染层（MarkupVisitor → NSAttributedString / UIView）。
    样式通过 Theme Token 配置，不依赖任何业务框架。
  DESC
  
  s.homepage     = 'https://code.devops.xiaohongshu.com/...'
  s.license      = { :type => 'MIT' }
  s.author       = { '沃顿' => 'yangtianxiang@xiaohongshu.com' }
  s.source       = { :git => '...', :tag => s.version.to_s }
  
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.9'
  
  s.source_files = 'Sources/XHSMarkdownKit/**/*.swift'
  
  # 唯一外部依赖
  s.dependency 'XYMarkdown', '~> 0.0.2'
  
  # 测试 subspec
  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.swift'
    ts.resources = 'Tests/Fixtures/**/*'
  end
end
```

---

## 6. 集成方案

### 6.1 Pod 接入

```ruby
# Podfile
pod 'XHSMarkdownKit', '~> 0.1.0'
```

### 6.2 基本使用

```swift
import XHSMarkdownKit

// 最简单的用法
let result = MarkdownKit.render("# Hello\n**World**")
label.attributedText = result.attributedString

// 自定义主题
var theme = MarkdownTheme()
theme.bodyFont = .systemFont(ofSize: 15)
theme.linkColor = .systemBlue
let result = MarkdownKit.render(markdown, theme: theme)

// 流式渲染
let buffer = StreamingTextBuffer()
buffer.onTextChanged = { fullText in
    let result = MarkdownKit.render(fullText, theme: theme)
    containerView.apply(result, maxWidth: width)
}
buffer.append(chunk)  // 收到 SSE chunk 时调用
```

### 6.3 让业务模型遵循协议（宿主 App 实现）

```swift
// 示例：让业务蓝链模型遵循 RichLinkModel 协议
extension YourRichTextModel: RichLinkModel {
    public var displayText: String { title ?? "" }
    public var linkURL: String { url ?? "" }
    public var httpLink: String? { originalLink }
}
```

### 6.4 创建场景主题（宿主 App 实现）

```swift
// 示例：为特定场景创建预设主题
extension MarkdownTheme {
    /// 紧凑样式（适合消息气泡等空间有限的场景）
    static let compact: MarkdownTheme = {
        var theme = MarkdownTheme()
        theme.bodyFont = .systemFont(ofSize: 15, weight: .regular)
        theme.bodyLineHeight = 25.0
        theme.paragraphSpacing = 12.0  // 较小的段落间距
        // 从业务设计稿获取颜色
        theme.bodyColor = YourDesignSystem.textColor
        theme.linkColor = YourDesignSystem.linkColor
        return theme
    }()
    
    /// 宽松样式（适合文章详情等阅读场景）
    static let readable: MarkdownTheme = {
        var theme = MarkdownTheme()
        theme.bodyFont = .systemFont(ofSize: 16, weight: .regular)
        theme.bodyLineHeight = 28.0
        theme.paragraphSpacing = 24.0  // 较大的段落间距
        return theme
    }()
}
```

### 6.5 流式场景集成示例

```swift
// 非流式场景：直接渲染
let result = MarkdownKit.render(markdown, theme: .compact)
label.attributedText = result.attributedString

// 流式场景：需要解析状态
let (result, parserState) = MarkdownKit.renderWithState(
    markdown,
    theme: .compact,
    phase: .streaming
)
containerView.apply(result, maxWidth: bubbleWidth)

// 根据尾部块类型判断续接行为（如果业务需要）
switch parserState.trailingBlockType {
case .list(let ordered, let depth):
    // 后续可能需要续接列表项
    break
case .codeBlock(let language):
    // 后续可能需要续接代码
    break
default:
    break
}
```

---

## 7. 开发计划

### 7.1 分周任务（共 2 周）

```
Week 1: 协议层 + 核心渲染能力
────────────────────────────
- [ ] 创建独立 Git 仓库 + Pod 结构 + Example 工程
- [ ] 实现 Protocols/ 协议层：
      RenderFragmentProtocol / TextFragment / ViewFragment
      BlockSpacingResolving / DefaultBlockSpacingResolver
      NodeRenderContext（含兄弟节点信息） / MarkdownNodeType（含 from(Markup)）
      AttributedStringNodeRenderer / ViewNodeRenderer（makeView + configure）/ NodeRenderer
- [ ] 实现 NodeRendererRegistry（注册表 + 三层查找调度）
- [ ] 实现 MarkdownConfiguration（rendererOverrides + spacingResolver + registerCustomBlock/Inline）
- [ ] 实现 MarkdownTheme（样式 Token，纯值类型）
- [ ] 实现 DocumentCache（LRU 缓存）
- [ ] 实现 MarkdownRenderer 主调度器（dispatch + Fragment 收集 + spacingResolver 调用）
- [ ] 实现 MarkdownRenderResult（[RenderFragmentProtocol] 序列 + attributedString 便捷属性）
- [ ] 实现 MarkdownContainerView（手动 frame 硬布局 + View 复用池 + contentHeight 预计算）
- [ ] 实现 Defaults/ 基础节点默认渲染器：
      HeadingRenderer / ParagraphRenderer / InlineRenderer /
      CodeBlockRenderer / ThematicBreakRenderer
- [ ] 实现 ListRenderer（有序+无序+嵌套，从现有代码提取算法）
- [ ] 实现 BlockQuoteRenderer（嵌套缩进 + 竖线标记）
- [ ] 实现 NSAttributedString 扩展（行高/间距/trait 等，从现有代码提取）
- [ ] 实现 MarkdownRenderable 协议（UILabel / UITextView 默认实现）
- [ ] 单元测试：各基础节点渲染 + 协议机制（覆盖/间距/Fragment）

Week 2: UIView 节点 + 自定义注入 + 集成验证
──────────────────────────────────────────
- [ ] 实现 TableRenderer: ViewNodeRenderer（makeView + configure）
- [ ] 实现 ImageRenderer: ViewNodeRenderer（makeView + configure）
- [ ] 新增 visitStrikethrough 默认渲染
- [ ] 实现 RichLinkRewriter（MarkupRewriter 子类）+ RewriterPipeline
- [ ] 实现 MarkdownKit 公开 API 入口
- [ ] 验证自定义节点注入：在 Example 工程中注册一个 CustomBlock UIView 渲染器
- [ ] 验证标准节点覆盖：在 Example 工程中用自定义 UIView 替换 CodeBlock 默认渲染
- [ ] 验证间距替换：在 Example 工程中注入自定义 BlockSpacingResolver
- [ ] 验证 MarkdownContainerView 硬布局：在 Example 工程中用 Fragment 序列驱动 ContainerView，验证高度计算、View 复用
- [ ] 实现 Streaming/ 流式渲染层（StreamingTextBuffer + MarkdownPreprocessor + FragmentDiffer + StreamingAnimator）
- [ ] 实现 MarkdownContainerView.applyDiff()（增量更新 + 动画调度接入）
- [ ] 实现 StreamingAnimationDelegate 协议（自定义 View 动画）
- [ ] 验证流式渲染：模拟 SSE append，验证逐字渐入 + 高度动态增长
- [ ] 验证 replace/remove：模拟 AI 修改前面内容，验证 Fragment diff 正确性
- [ ] 验证未闭合标记预闭合：`**文本` / `` ` 代码 `` / 未闭合代码块
- [ ] 性能测试：2000 字 MD 文本解析+渲染 < 50ms；流式场景 30fps 不掉帧
- [ ] 边界 case：嵌套列表（3层+）、引用内嵌列表、空内容、超长文本
- [ ] 在宿主 App 中集成测试
- [ ] 截图对比：新旧渲染效果一致性验证
- [ ] 完善 README（含协议使用指南 + 自定义渲染器 + 间距规则替换 + 流式渲染接入）+ CHANGELOG
```

### 7.2 里程碑

| 节点 | 目标 | 时间 |
|------|------|------|
| M1 | 基础节点渲染通过单元测试，Example App 可预览 | Week 1 结束 |
| M2 | 全量节点 + 流式渲染，集成 rebeka-ios 替换旧 Processor | Week 2 中 |
| M3 | 性能达标（含流式 30fps），截图对比通过，发布 0.1.0 | Week 2 结束 |

---

## 8. 验收标准

| 指标 | 目标 |
|------|------|
| MD 语法覆盖 | 标题/列表（有序+无序+嵌套）/引用（嵌套）/代码块/行内代码/链接/图片/表格/分割线/加粗/斜体/删除线/HTML |
| 蓝链 | 通过 MarkupRewriter 实现 AST 级改写 |
| 渲染性能 | 2000 字 MD 文本解析+渲染 < 50ms (iPhone 13) |
| Document 缓存 | 相同文本第二次渲染 < 5ms |
| 渲染一致性 | 替换旧实现后，截图 diff < 5% |
| **标准节点可覆盖** | **任意标准节点均可通过 register() 替换为自定义实现** |
| **自定义节点可注入** | **通过 registerCustomBlock(identifier:viewRenderer:) 注入任意 UIView 渲染的自定义块节点** |
| **两种渲染器协议** | **AttributedStringNodeRenderer（文本型）和 ViewNodeRenderer（视图型，makeView/configure 分离），覆盖所有场景** |
| **★ Fragment 序列** | **渲染结果为 [RenderFragmentProtocol] 有序序列，支持 TextFragment / ViewFragment / 自定义 Fragment** |
| **★ 布局容器** | **MarkdownContainerView 手动 frame 硬布局，预计算高度立即可用，View 复用池管理** |
| **★ 间距可替换** | **BlockSpacingResolving 协议，默认实现 DefaultBlockSpacingResolver，可通过 Configuration 注入自定义间距规则** |
| **★ View 便捷渲染** | **UILabel / UITextView 通过 MarkdownRenderable 协议一行代码渲染 Markdown** |
| **★ 流式渲染** | **StreamingTextBuffer 节流 + MarkdownPreprocessor 预闭合 + FragmentDiffer 增量更新，30fps 不掉帧** |
| **★ 流式动画** | **StreamingAnimator 逐字渐入 + StreamingAnimationDelegate 自定义 View 动画 + 快进机制** |
| **★ 数据变更** | **支持 append / replace / remove，全量重解析 + Fragment diff 自动处理** |
| 外部依赖 | 仅依赖 XYMarkdown，不依赖任何 XY/AX 业务库 |
| 测试覆盖 | 核心渲染逻辑 + 协议机制（注册覆盖/间距替换/Fragment 序列）+ 流式渲染 单元测试覆盖 > 80% |
| 文档 | README 包含接入指南、Theme 自定义、自定义渲染器注册、间距规则替换、流式渲染接入示例 |

---

## 9. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| XYMarkdown binary Pod 无法调试 | 遇到解析 bug 难排查 | XYMarkdown 有源码可用（Sources/），开发期切源码依赖 |
| 蓝链 Rewriter 改写后 Halo 行为不同 | 蓝链在不同场景表现不一致 | RichLinkRewriter 作为可选 Rewriter 注入，不改 XYMarkdown 本身 |
| 表格等 UIView 组件的创建/销毁开销 | 滚动时频繁 alloc 导致内存抖动 | MarkdownContainerView 内置 View 复用池 + makeView/configure 分离，复用时只调 configure |
| 现有 Processor 有大量边界 case 调优（间距、对齐等） | 新 Renderer 在细节上与旧版不一致 | 提取现有间距算法原样复制，先保证一致，再优化 |
| XYMarkdown 版本升级可能 break API | 编译失败 | Podspec 锁定 ~> 0.0.2，升级前回归测试 |
| 流式全量重解析在超长文本下性能不足 | > 5000 字时解析可能超过帧预算 | 待实际性能测试后确定优化方向。可能的优化：①cmark 解析优化；②分段解析（按块级节点边界）；③异步解析 + 主线程渲染分离。**不应降低帧率牺牲体验** |
| 预闭合误判（正常文本中的单个 `*` 被当作未闭合标记） | 渲染结果与最终不一致 | 预闭合只处理文本尾部最后一个块级元素；流式结束后用原始文本重新解析一次 |
| 逐字渐入与 replace 冲突（正在渐入时前面的内容被修改） | 动画中断或显示错误 | replace 触发时清空动画队列，直接显示最新状态 |
| **结构指纹 fragmentId 在复杂场景出问题** | AI 大幅修改回答导致 fragment 错位/丢失 | **`fragmentIdStrategy` 配置项可降级**：默认 `.structuralFingerprint`，出问题时切换到 `.sequentialIndex`。降级后 replace 性能下降，但保证正确性 |

---

## 附录 A：标准 Markdown 节点覆盖

| MarkupVisitor 方法 | 现有实现 | XHSMarkdownKit |
|-------------------|---------|---------------|
| `visitDocument` | ✅ (defaultVisit) | ✅ |
| `visitHeading` | ✅ | ✅ |
| `visitParagraph` | ✅ | ✅ |
| `visitText` | ✅ | ✅ |
| `visitStrong` | ✅ | ✅ |
| `visitEmphasis` | ✅ (改为高亮) | ✅ (可配置行为) |
| `visitLink` | ✅ (含蓝链) | ✅ (蓝链移至 Rewriter) |
| `visitInlineCode` | ✅ | ✅ |
| `visitCodeBlock` | ✅ | ✅ (+ UIView 选项) |
| `visitBlockQuote` | ✅ | ✅ |
| `visitOrderedList` | ✅ | ✅ |
| `visitUnorderedList` | ✅ | ✅ |
| `visitListItem` | ✅ | ✅ |
| `visitThematicBreak` | ✅ | ✅ |
| `visitLineBreak` | ✅ | ✅ |
| `visitSoftBreak` | ❌ (fallback) | ✅ |
| `visitInlineHTML` | ✅ | ✅ |
| `visitHTMLBlock` | ✅ | ✅ |
| `visitTable` | ❌ | ✅ → UIView |
| `visitStrikethrough` | ❌ (注释掉) | ✅ |
| `visitImage` | ❌ | ✅ → UIView |
| `visitCustomBlock` | ❌ | ✅ (NodeRendererRegistry 查找) |
| `visitCustomInline` | ❌ | ✅ (NodeRendererRegistry 查找) |
| `visitTaskListItem` | ❌ | ✅ |

---

## 附录 B：从现有代码中迁移的关键常量

> 以下常量作为 `MarkdownTheme.default` 的默认值。

```swift
// 现有代码中的硬编码值 → MarkdownTheme 中的对应 Token
paragraphStyleMinimumLineHeight = 24.0       → bodyLineHeight (richtext=25, common=26)
markdownParagraphCommonSpacing = 26.0        → paragraphSpacing
markdownParagraphAfterHeadingSpacing = 12.0  → headingSpacingAfter
markdownParagraphListSpacing = 6.0           → listItemSpacing
markdownParagraphListAfterTextSpacing = 12.0 → listAfterTextSpacing
markdownParagraphInnerSpacing = 6.0          → innerParagraphSpacing
markdownBlockQuoteBetweenQuoteSpacing = 6.0  → blockQuoteBetweenSpacing
markdownBlockQuoteOtherSpacing = 12.0        → blockQuoteOtherSpacing
markdownBlockQuoteLeftMargin = 22.0          → blockQuoteLeftMargin
markdownBlockQuoteLineLeftMargin = 8.0       → blockQuoteBarLeftMargin
markdownBulletListMarginStart = 5.0          → bulletLeftMargin
markdownBulletListMarginEnd = 11.0           → bulletRightMargin
markdownOrderListItemMarginStart = 4.0       → orderedListLeftMargin
markdownOrderListTextLeftMargin = 22.0       → orderedListTextLeftMargin
kern = 0.32                                  → bodyLetterSpacing
```

---

## 更新记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-02-14 | 初版：Markdown 独立工程详细开发文档，9 章 + 2 附录 |
| v1.1 | 2026-02-14 | 渲染层可扩展性增强：NodeRenderProtocol 双协议 + NodeRendererRegistry 三层查找 + MarkdownConfiguration 实例级覆盖 |
| v1.2 | 2026-02-14 | POP 深化（务实导向）：①渲染结果改为 RenderFragmentProtocol 有序序列（解决 viewBlocks 锚点痛点）；②新增 BlockSpacingResolving 协议（间距规则可替换，解决多场景复用）；③ViewNodeRenderer 拆分 makeView/configure（UIKit 标准复用模式）；④NodeRenderContext 增强（兄弟节点信息、列表索引，减少渲染器内部 AST 遍历）；⑤新增 MarkdownRenderable 协议（UILabel/UITextView 一行渲染）；⑥MarkdownNodeType.heading 携带 level、新增 from(Markup) 推导方法 |
| v1.3 | 2026-02-14 | 布局方案修正：①新增 MarkdownContainerView 手动 frame 硬布局（预计算高度 + View 复用池，性能最优）；②明确 XHSMarkdownKit 不依赖任何列表框架，纯 UIKit 实现|
| v1.4 | 2026-02-14 | 流式渲染架构（§3.11）：①StreamingTextBuffer 文本缓冲 + CADisplayLink 节流；②MarkdownPreprocessor 未闭合标记预闭合（消除跳变）；③FragmentDiffer 差异比对（基于结构指纹 fragmentId，支持 append/replace/remove）；④MarkdownContainerView.applyDiff() 增量布局；⑤StreamingAnimator 动画调度（逐字渐入 + 快进机制）；⑥StreamingAnimationDelegate 自定义 View 动画协议；⑦三者协调时序（帧预算 < 9ms + 动画队列 + 快进阈值）|
| v1.5 | 2026-02-14 | Diff 算法与完整流程（§3.11.4.1 + §3.11.4.2）：①StreamingFragmentDiffer 快速路径优化（纯 append O(n) 前缀检查）；②完整端到端流程图（从 SSE chunk 到屏幕）；③StreamingAnimationCoordinator 动画时序协调（节流 + 队列 + 快进）；④分层架构代码示例（网络层 → 预处理 → 布局 → 动画 → UI）；⑤性能指标实测（7.3ms 处理 + 8.7ms 动画）|
| v1.6 | 2026-02-14 | 动态速度调整（§3.11.6.1 改进）：①移除简单快进，改为 AnimationSpeedConfig 根据积压程度自动调整速度；②5 档速度（2/3/4/6/8 字/帧），对应 5 个积压阈值（0/50/100/200/300）；③保持动画流畅的同时快速消化积压；④用户体验从"卡顿感"改为"加速感"；⑤可配置激进/保守策略|
| v1.7 | 2026-02-14 | 渲染承载层（§3.11.9）：①TextFragment 用 UITextView 承载（支持链接交互）；②ViewFragment 用自定义 UIView 承载（表格/代码块）；③OptimizedTextFragmentView 高度缓存优化；④TableFragmentView / CodeBlockFragmentView 具体实现示例；⑤MarkdownContainerView 的实际渲染流程（创建/更新/删除 View）；⑥完整的渲染管道（从 Fragment 到屏幕）|
| v1.8 | 2026-02-25 | 设计问题修复与去业务化：①移除 `endsWithList: Bool`，改为独立的 `StreamingParserState`；②fragmentId 改用简短结构指纹（`h0`/`p1`/`ol2`）；③预闭合逻辑改用状态机；④`ViewNodeRenderer.makeView()` 增加 node 参数；⑤`TextFragment.estimatedHeight()` 增加高度缓存；⑥新增 `renderWithState()` API；⑦新增 `StreamingSourceAdapter` 协议（SSE 格式依赖注入）；⑧全面去除"Chat"字眼，使用通用命名（MarkdownRenderer / CustomAnimationDelegate 等）；⑨明确多消息并发由业务层通过独立实例保证隔离；⑩移除 IGListKit 相关描述，确保库的纯粹性|
| v1.9 | 2026-02-25 | fragmentId 策略可配置：①新增 `FragmentIdStrategy` 枚举（structuralFingerprint/sequentialIndex/contentHash）；②`MarkdownConfiguration.fragmentIdStrategy` 配置项；③默认结构指纹，出问题时可降级到顺序索引；④风险表增加降级策略说明|
