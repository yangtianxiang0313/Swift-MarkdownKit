import UIKit

/// MarkdownImageView 的配置结构体
public struct ImageConfiguration {
    
    // MARK: - 内容
    
    public let source: String?
    public let maxWidth: CGFloat
    
    // MARK: - 样式配置
    
    public let cornerRadius: CGFloat
    public let placeholderHeight: CGFloat
    public let placeholderColor: UIColor
    public let maxImageWidth: CGFloat
    
    // MARK: - Init
    
    public init(
        source: String?,
        maxWidth: CGFloat,
        cornerRadius: CGFloat,
        placeholderHeight: CGFloat,
        placeholderColor: UIColor,
        maxImageWidth: CGFloat
    ) {
        self.source = source
        self.maxWidth = maxWidth
        self.cornerRadius = cornerRadius
        self.placeholderHeight = placeholderHeight
        self.placeholderColor = placeholderColor
        self.maxImageWidth = maxImageWidth
    }
}
