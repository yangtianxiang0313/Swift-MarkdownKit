import UIKit

public struct ImageContent {
    public let source: String?
    public let title: String?
    public let altText: String

    public init(source: String?, title: String?, altText: String) {
        self.source = source
        self.title = title
        self.altText = altText
    }
}

public protocol ImageViewStrategy {
    func makeView() -> UIView
    func configure(view: UIView, content: ImageContent, context: FragmentContext, theme: MarkdownTheme)
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}

public extension ImageViewStrategy {
    var enterTransition: (any ViewTransition)? { nil }
    var exitTransition: (any ViewTransition)? { nil }
}

public enum ImageViewStrategyKey: ContextKey {
    public static let defaultValue: ImageViewStrategy = DefaultImageViewStrategy()
}

public struct DefaultImageViewStrategy: ImageViewStrategy {
    public init() {}
    public func makeView() -> UIView { MarkdownImageView() }
    public func configure(view: UIView, content: ImageContent, context: FragmentContext, theme: MarkdownTheme) {
        guard let imageView = view as? MarkdownImageView else { return }
        imageView.configure(source: content.source, maxWidth: context[MaxWidthKey.self], theme: theme.image)
    }
}
