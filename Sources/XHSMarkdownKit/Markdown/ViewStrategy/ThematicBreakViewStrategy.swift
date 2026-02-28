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
    public static let defaultValue: ThematicBreakViewStrategy = DefaultThematicBreakViewStrategy()
}

public struct DefaultThematicBreakViewStrategy: ThematicBreakViewStrategy {
    public init() {}
    public func makeView() -> UIView { ThematicBreakView() }
    public func configure(view: UIView, context: FragmentContext, theme: MarkdownTheme) {
        guard let breakView = view as? ThematicBreakView else { return }
        breakView.configure(color: theme.thematicBreak.color, height: theme.thematicBreak.height)
    }
}
