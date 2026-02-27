import Foundation
import UIKit

// MARK: - 核心 Context Keys

/// 框架提供的核心 Keys，覆盖 99% 渲染场景需求
/// 用户可以定义自己的 Key 来扩展（无需修改此文件）

/// 主题样式
public enum ThemeKey: ContextKey {
    public static var defaultValue: MarkdownTheme { .default }
}

/// 最大宽度
public enum MaxWidthKey: ContextKey {
    public static var defaultValue: CGFloat { .greatestFiniteMagnitude }
}

/// 当前缩进（累积计算值）
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

/// 当前节点在父节点中的索引
public enum IndexInParentKey: ContextKey {
    public static var defaultValue: Int { 0 }
}

/// Fragment 外部状态存储
public enum StateStoreKey: ContextKey {
    public static var defaultValue: FragmentStateStore { FragmentStateStore() }
}

// MARK: - Key 清单

/*
 | Key                 | 类型            | 默认值 | 用途               |
 |---------------------|-----------------|--------|-------------------|
 | ThemeKey            | MarkdownTheme   | .default | 样式主题         |
 | MaxWidthKey         | CGFloat         | ∞       | 最大宽度          |
 | IndentKey           | CGFloat         | 0       | 当前缩进（累积）   |
 | PathPrefixKey       | String          | ""      | Fragment ID 前缀  |
 | ListDepthKey        | Int             | 0       | 列表嵌套深度      |
 | BlockQuoteDepthKey  | Int             | 0       | 引用块嵌套深度    |
 
 其他信息：
 - 从【节点本身】获取（如 listItem.indexInParent、orderedList.startIndex）
 - 或【自定义 Key】扩展
 */
