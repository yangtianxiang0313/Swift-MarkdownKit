import UIKit
@testable import XHSMarkdownKit

func render(
    _ markdown: String,
    registry: RendererRegistry = .makeDefault(),
    spacingResolver: BlockSpacingResolving = DefaultBlockSpacingResolver(),
    rewriterPipeline: RewriterPipeline? = nil,
    maxWidth: CGFloat = 320,
    theme: MarkdownTheme = .default
) -> [RenderFragment] {
    let pipeline = MarkdownRenderPipeline(
        parser: XYMarkdownParser(),
        rendererRegistry: registry,
        spacingResolver: spacingResolver,
        rewriterPipeline: rewriterPipeline
    )

    return pipeline.render(
        markdown,
        maxWidth: maxWidth,
        theme: theme,
        stateStore: nil
    )
}

func mergedText(from fragments: [RenderFragment]) -> String {
    let merged = NSMutableAttributedString(string: "")
    for fragment in fragments {
        if let text = (fragment as? AttributedStringProviding)?.attributedString {
            merged.append(text)
            merged.append(NSAttributedString(string: "\n"))
        }
    }
    return merged.string
}

final class FixedTextRenderer: LeafNodeRenderer {
    private let text: String

    init(text: String) {
        self.text = text
    }

    func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        let attributed = NSAttributedString(string: text)
        return [ViewFragment(
            fragmentId: context.fragmentId(nodeType: "override", index: 0),
            nodeType: node.nodeType,
            reuseIdentifier: .textView,
            context: context.makeFragmentContext(),
            content: attributed,
            totalContentLength: attributed.length,
            makeView: { MarkdownTextView() },
            configure: { view in
                (view as? MarkdownTextView)?.configure(
                    attributedString: attributed,
                    indent: 0
                )
            }
        )]
    }
}

final class FixedSpacingResolver: BlockSpacingResolving {
    let value: CGFloat

    init(_ value: CGFloat) {
        self.value = value
    }

    func spacing(after current: FragmentNodeType, before next: FragmentNodeType, theme: MarkdownTheme) -> CGFloat {
        value
    }
}

final class EmptyDocumentNode: DocumentNode {
    let nodeType: FragmentNodeType = .document
    let children: [MarkdownNode] = []
}
