import UIKit

// MARK: - Markdown 层 ContextKey 定义

public enum ThemeKey: ContextKey {
    public static let defaultValue = MarkdownTheme()
}

public enum MaxWidthKey: ContextKey {
    public static let defaultValue: CGFloat = 0
}

public enum IndentKey: ContextKey {
    public static let defaultValue: CGFloat = 0
}

public enum ListDepthKey: ContextKey {
    public static let defaultValue: Int = 0
}

public enum BlockQuoteDepthKey: ContextKey {
    public static let defaultValue: Int = 0
}

public enum ListItemIndexKey: ContextKey {
    public static let defaultValue: Int? = nil
}

public enum IsOrderedListKey: ContextKey {
    public static let defaultValue: Bool = false
}
