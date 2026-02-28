import UIKit

public protocol TextViewStrategy {
    func makeView() -> UIView
    func configure(view: UIView, attributedString: NSAttributedString, context: FragmentContext, theme: MarkdownTheme)
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}

public extension TextViewStrategy {
    var enterTransition: (any ViewTransition)? { nil }
    var exitTransition: (any ViewTransition)? { nil }
}

public enum TextViewStrategyKey: ContextKey {
    public static let defaultValue: TextViewStrategy = DefaultTextViewStrategy()
}

public struct DefaultTextViewStrategy: TextViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        MarkdownTextView()
    }

    public func configure(view: UIView, attributedString: NSAttributedString, context: FragmentContext, theme: MarkdownTheme) {
        guard let textView = view as? MarkdownTextView else { return }
        let indent = context[IndentKey.self]
        textView.configure(
            attributedString: attributedString,
            indent: indent
        )
    }
}
