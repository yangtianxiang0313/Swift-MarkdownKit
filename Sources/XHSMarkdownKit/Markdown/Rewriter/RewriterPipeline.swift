import Foundation

public struct RewriterPipeline {
    public typealias Rewriter = (MarkdownNode) -> MarkdownNode

    private let rewriters: [Rewriter]

    public init(rewriters: [Rewriter] = []) {
        self.rewriters = rewriters
    }

    public func rewrite(_ node: MarkdownNode) -> MarkdownNode {
        rewriters.reduce(node) { current, rewriter in
            rewriter(current)
        }
    }
}
