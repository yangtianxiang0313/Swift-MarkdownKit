import XCTest
@testable import XHSMarkdownKit

final class CanonicalRewritePipelineTests: XCTestCase {

    func testRewriteRuleCanAdjustStandardNodeAttrs() throws {
        let document = makeDocumentWithHeading(level: 1)

        let pipeline = MarkdownContract.CanonicalRewritePipeline(rules: [
            .init(id: "normalize-heading", priority: 10, phase: .preChildren) { node, _ in
                guard node.kind == .heading else { return node }
                var updated = node
                updated.attrs["level"] = .int(2)
                return updated
            }
        ])

        let rewritten = try pipeline.rewrite(document)
        let heading = rewritten.root.children.first

        XCTAssertEqual(heading?.attrs["level"], .int(2))
    }

    func testRewriteRuleSupportsPostChildrenPhase() throws {
        let paragraph = MarkdownContract.CanonicalNode(
            id: "p",
            kind: .paragraph,
            children: [
                MarkdownContract.CanonicalNode(
                    id: "t",
                    kind: .text,
                    attrs: ["text": .string("hello")],
                    source: .init(sourceKind: .markdown)
                )
            ],
            source: .init(sourceKind: .markdown)
        )

        let document = MarkdownContract.CanonicalDocument(
            documentId: "doc",
            root: MarkdownContract.CanonicalNode(
                id: "root",
                kind: .document,
                children: [paragraph],
                source: .init(sourceKind: .markdown)
            )
        )

        let pipeline = MarkdownContract.CanonicalRewritePipeline(rules: [
            .init(id: "count-children", phase: .postChildren) { node, context in
                guard node.kind == .paragraph, context.phase == .postChildren else {
                    return node
                }
                var updated = node
                updated.attrs["childCount"] = .int(node.children.count)
                return updated
            }
        ])

        let rewritten = try pipeline.rewrite(document)
        let rewrittenParagraph = rewritten.root.children.first

        XCTAssertEqual(rewrittenParagraph?.attrs["childCount"], .int(1))
    }

    func testHigherPriorityRuleExecutesFirst() throws {
        let document = makeDocumentWithHeading(level: 1)

        let pipeline = MarkdownContract.CanonicalRewritePipeline(rules: [
            .init(id: "low", priority: 1) { node, _ in
                guard node.kind == .heading else { return node }
                var updated = node
                updated.attrs["order"] = .array([.string("low")])
                return updated
            },
            .init(id: "high", priority: 10) { node, _ in
                guard node.kind == .heading else { return node }
                var updated = node
                let existing = (updated.attrs["order"] ?? .array([]))
                let values: [MarkdownContract.Value]
                if case let .array(array) = existing {
                    values = [.string("high")] + array
                } else {
                    values = [.string("high")]
                }
                updated.attrs["order"] = .array(values)
                return updated
            }
        ])

        let rewritten = try pipeline.rewrite(document)
        let heading = rewritten.root.children.first

        XCTAssertEqual(heading?.attrs["order"], .array([.string("high"), .string("low")]))
    }

    private func makeDocumentWithHeading(level: Int) -> MarkdownContract.CanonicalDocument {
        MarkdownContract.CanonicalDocument(
            documentId: "doc",
            root: MarkdownContract.CanonicalNode(
                id: "root",
                kind: .document,
                children: [
                    MarkdownContract.CanonicalNode(
                        id: "h1",
                        kind: .heading,
                        attrs: ["level": .int(level)],
                        source: .init(sourceKind: .markdown)
                    )
                ],
                source: .init(sourceKind: .markdown)
            )
        )
    }
}
