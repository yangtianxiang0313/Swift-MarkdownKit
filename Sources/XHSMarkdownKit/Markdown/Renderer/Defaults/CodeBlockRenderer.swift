import UIKit

public struct DefaultCodeBlockRenderer: LeafNodeRenderer {
    public init() {}

    public func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard let codeBlock = node as? CodeBlockNode else { return [] }
        let code = codeBlock.code
        let language = codeBlock.language

        let stateKey = "\(code.hashValue)_\(language ?? "")"
        let content = CodeBlockContent(code: code, language: language, stateKey: stateKey)
        let strategy = context[CodeBlockViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()
        let theme = context.theme
        let fragmentId = context.fragmentId(nodeType: "codeBlock", index: 0)

        return [ViewFragment(
            fragmentId: fragmentId,
            nodeType: .codeBlock,
            reuseIdentifier: .codeBlockView,
            context: fragmentContext,
            content: content,
            totalContentLength: code.count,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, content: content, context: fragmentContext, theme: theme)
            }
        )]
    }
}
