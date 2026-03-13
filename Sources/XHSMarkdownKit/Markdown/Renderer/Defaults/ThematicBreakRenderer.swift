import UIKit

public struct DefaultThematicBreakRenderer: LeafNodeRenderer {
    public init() {}

    public func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard node is ThematicBreakNode else { return [] }

        let strategy = context[ThematicBreakViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()
        let theme = context.theme
        let fragmentId = context.fragmentId(nodeType: "thematicBreak", index: 0)

        return [ViewFragment(
            fragmentId: fragmentId,
            nodeType: .thematicBreak,
            reuseIdentifier: .thematicBreakView,
            context: fragmentContext,
            content: EmptyFragmentContent(),
            totalContentLength: 1,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, context: fragmentContext, theme: theme)
            }
        )]
    }
}
