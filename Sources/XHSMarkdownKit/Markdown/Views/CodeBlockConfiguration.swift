import UIKit

/// CodeBlockView 的配置结构体
/// 封装了渲染代码块所需的所有参数，View 不依赖 MarkdownTheme
public struct CodeBlockConfiguration {
    
    // MARK: - 内容
    
    public let code: String
    public let language: String?
    
    // MARK: - 样式配置
    
    public let backgroundColor: UIColor
    public let font: UIFont
    public let cornerRadius: CGFloat
    public let borderWidth: CGFloat
    public let borderColor: CGColor
    public let padding: UIEdgeInsets
    
    // MARK: - Init
    
    public init(
        code: String,
        language: String?,
        backgroundColor: UIColor,
        font: UIFont,
        cornerRadius: CGFloat,
        borderWidth: CGFloat,
        borderColor: CGColor,
        padding: UIEdgeInsets
    ) {
        self.code = code
        self.language = language
        self.backgroundColor = backgroundColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.padding = padding
    }
}
