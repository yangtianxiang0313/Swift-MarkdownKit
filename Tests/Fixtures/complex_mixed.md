# 复杂混合 Markdown 测试

这是一个包含多种 Markdown 元素的复杂文档，用于测试渲染器的综合能力。

## 文本样式组合

这是一段包含 **加粗**、*斜体*、***加粗斜体***、`行内代码`、~~删除线~~ 的文本。

还可以组合：**加粗中包含 `代码`**、*斜体中包含 **加粗***、~~删除线中包含 **加粗**~~。

## 链接与图片

这是一个 [普通链接](https://example.com)。

这是一个带标题的 [链接](https://example.com "链接标题")。

这是一张图片：

![示例图片](https://example.com/image.png)

## 引用块

> 这是一段引用。
> 
> 引用可以包含多个段落。

> 引用中也可以包含其他元素：
> 
> - 列表项 1
> - 列表项 2
> 
> ```swift
> let quote = "引用中的代码"
> ```

### 嵌套引用

> 外层引用
> 
> > 内层引用
> > 
> > > 三层嵌套引用

## 代码块

行内代码：`let x = 42`

带语言标注的代码块：

```swift
import Foundation

struct MarkdownRenderer {
    let theme: Theme
    
    func render(_ markdown: String) -> NSAttributedString {
        // 解析并渲染
        let document = Document(parsing: markdown)
        return visit(document)
    }
}
```

不带语言标注的代码块：

```
这是纯文本代码块
没有语法高亮
```

## 表格

| 功能 | 状态 | 备注 |
|------|:----:|-----:|
| 解析 | ✅ | 基于 cmark |
| 渲染 | ✅ | MarkupVisitor |
| 缓存 | ✅ | LRU 缓存 |
| 流式 | ✅ | CADisplayLink |

## 分割线

上面的内容。

---

下面的内容。

***

还有一种写法。

___

## 任务列表

- [ ] 未完成任务
- [x] 已完成任务
- [ ] 另一个未完成任务
  - [x] 子任务已完成
  - [ ] 子任务未完成

## HTML 内容

<div style="color: red;">这是 HTML 内容</div>

行内 HTML：这是 <strong>HTML 加粗</strong> 文本。

## 转义字符

\*这不是斜体\*

\`这不是代码\`

\# 这不是标题

## 特殊字符

Unicode 表情：😀 🎉 ✨ 🚀

中文标点：，。！？、；：""''【】

数学符号：∑ ∏ ∫ √ ∞ ≠ ≤ ≥

## 超长段落

这是一个超长的段落，用于测试文本换行和布局的正确性。Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

## 紧邻元素

**加粗**紧跟普通文本
普通文本紧跟**加粗**

1. 列表项
紧跟段落

> 引用
紧跟段落
