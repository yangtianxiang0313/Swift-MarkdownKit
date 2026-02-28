import UIKit

public struct CodeBlockContent {
    public let code: String
    public let language: String?
    public let stateKey: String

    public init(code: String, language: String?, stateKey: String) {
        self.code = code
        self.language = language
        self.stateKey = stateKey
    }
}

public protocol CodeBlockViewStrategy {
    func makeView() -> UIView
    func configure(view: UIView, content: CodeBlockContent, context: FragmentContext, theme: MarkdownTheme)
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}

public extension CodeBlockViewStrategy {
    var enterTransition: (any ViewTransition)? { nil }
    var exitTransition: (any ViewTransition)? { nil }
}

public enum CodeBlockViewStrategyKey: ContextKey {
    public static let defaultValue: CodeBlockViewStrategy = DefaultCodeBlockViewStrategy()
}

public struct DefaultCodeBlockViewStrategy: CodeBlockViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        CodeBlockView()
    }

    public func configure(view: UIView, content: CodeBlockContent, context: FragmentContext, theme: MarkdownTheme) {
        guard let codeView = view as? CodeBlockView else { return }
        codeView.configure(
            code: content.code,
            language: content.language,
            theme: theme.code
        )
    }
}
