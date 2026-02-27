//
//  Markup+Sibling.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import XYMarkdown

// MARK: - Markup 节点遍历辅助

public extension Markup {
    
    /// 获取第一个子节点
    var firstChild: Markup? {
        children.first(where: { _ in true })
    }
    
    /// 获取最后一个子节点
    var lastChild: Markup? {
        var last: Markup? = nil
        for child in children {
            last = child
        }
        return last
    }
    
    /// 是否为第一个子节点
    var isFirstChild: Bool {
        indexInParent == 0
    }
    
    /// 是否为最后一个子节点
    var isLastChild: Bool {
        guard let parent = parent else { return true }
        return indexInParent == parent.childCount - 1
    }
    
    /// 获取所有文本内容（递归）
    var plainText: String {
        var result = ""
        collectPlainText(from: self, into: &result)
        return result
    }
}

// MARK: - 私有辅助

private func collectPlainText(from node: Markup, into result: inout String) {
    if let text = node as? Text {
        result += text.string
    } else if node is SoftBreak {
        result += " "
    } else if node is LineBreak {
        result += "\n"
    } else {
        for child in node.children {
            collectPlainText(from: child, into: &result)
        }
    }
}

// MARK: - 节点类型判断

public extension Markup {
    
    /// 是否为块级节点
    var isBlockLevel: Bool {
        self is Document ||
        self is Paragraph ||
        self is Heading ||
        self is BlockQuote ||
        self is CodeBlock ||
        self is OrderedList ||
        self is UnorderedList ||
        self is ListItem ||
        self is Table ||
        self is ThematicBreak ||
        self is HTMLBlock
    }
    
    /// 是否为行内节点
    var isInline: Bool {
        !isBlockLevel
    }
    
    /// 是否为列表节点
    var isList: Bool {
        self is OrderedList || self is UnorderedList
    }
    
    /// 是否为列表项
    var isListItem: Bool {
        self is ListItem
    }
}

// MARK: - 深度遍历

public extension Markup {
    
    /// 深度优先遍历所有子节点
    func forEachDescendant(_ body: (Markup) -> Void) {
        for child in children {
            body(child)
            child.forEachDescendant(body)
        }
    }
    
    /// 查找第一个满足条件的子节点
    func firstDescendant(where predicate: (Markup) -> Bool) -> Markup? {
        for child in children {
            if predicate(child) {
                return child
            }
            if let found = child.firstDescendant(where: predicate) {
                return found
            }
        }
        return nil
    }
    
    /// 计算节点深度
    var depth: Int {
        var d = 0
        var current: Markup? = parent
        while current != nil {
            d += 1
            current = current?.parent
        }
        return d
    }
}
