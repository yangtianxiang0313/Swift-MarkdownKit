import UIKit

public protocol ThematicBreakViewStrategy {
    func makeView() -> UIView
    func configure(view: UIView, context: FragmentContext, theme: MarkdownTheme)
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}

public extension ThematicBreakViewStrategy {
    var enterTransition: (any ViewTransition)? { nil }
    var exitTransition: (any ViewTransition)? { nil }
}

public enum ThematicBreakViewStrategyKey: ContextKey {
    public static let defaultValue: ThematicBreakViewStrategy = DefaultContractThematicBreakViewStrategy()
}
