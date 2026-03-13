import UIKit

public struct ImageContent: FragmentContent {
    public let source: String?
    public let title: String?
    public let altText: String

    public init(source: String?, title: String?, altText: String) {
        self.source = source
        self.title = title
        self.altText = altText
    }

    public func isEqual(to other: any FragmentContent) -> Bool {
        guard let rhs = other as? ImageContent else { return false }
        return source == rhs.source
            && title == rhs.title
            && altText == rhs.altText
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
    public static let defaultValue: ImageViewStrategy = DefaultContractImageViewStrategy()
}
