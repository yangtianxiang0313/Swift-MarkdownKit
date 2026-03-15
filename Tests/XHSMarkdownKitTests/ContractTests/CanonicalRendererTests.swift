import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class CanonicalRendererTests: XCTestCase {

    func testEngineRendersHeadingAndParagraph() throws {
        let engine = MarkdownnAdapter.makeEngine()

        let model = try engine.render(
            "# Title\n\nBody",
            parseOptions: .init(documentId: "doc-render")
        )

        XCTAssertEqual(model.schemaVersion, MarkdownContract.schemaVersion)
        XCTAssertEqual(model.documentId, "doc-render")
        XCTAssertTrue(model.blocks.contains(where: { $0.kind == .heading }))
        XCTAssertTrue(model.blocks.contains(where: { $0.kind == .paragraph }))
    }

    func testCustomBlockRendererOverridesStandardNode() throws {
        let registry = MarkdownContract.CanonicalRendererRegistry.makeDefault()
        registry.registerBlockRenderer(for: .heading) { node, _, _ in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: .custom,
                metadata: ["overridden": .bool(true)]
            )]
        }

        let renderer = MarkdownContract.DefaultCanonicalRenderer(registry: registry)
        let engine = MarkdownContractEngine(parser: XYMarkdownContractParser(), renderer: renderer)

        let model = try engine.render("# Title")
        let customHeading = model.blocks.first

        XCTAssertEqual(customHeading?.kind, .custom)
        XCTAssertEqual(customHeading?.metadata["overridden"], .bool(true))
    }

    func testNodeStyleSheetAndThemeTokensAppliedToBlock() throws {
        let root = MarkdownContract.CanonicalNode(
            id: "root",
            kind: .document,
            children: [
                MarkdownContract.CanonicalNode(
                    id: "p1",
                    kind: .paragraph,
                    children: [
                        MarkdownContract.CanonicalNode(
                            id: "t1",
                            kind: .text,
                            attrs: ["text": .string("hello")],
                            source: .init(sourceKind: .markdown)
                        )
                    ],
                    source: .init(sourceKind: .markdown)
                )
            ],
            source: .init(sourceKind: .markdown)
        )
        let document = MarkdownContract.CanonicalDocument(documentId: "style-doc", root: root)

        let options = MarkdownContract.CanonicalRenderOptions(
            themeTokens: .init(values: [
                "text.color": .color(.init(token: "text.primary"))
            ]),
            nodeStyleSheet: .init(byNodeKind: [
                "paragraph": .init(
                    inheritFromParent: false,
                    themeTokenRefs: ["text.color"],
                    styleTokens: [.init(name: "spacing.after", value: .number(12))]
                )
            ])
        )

        let model = try MarkdownContract.DefaultCanonicalRenderer().render(document: document, options: options)
        guard let paragraph = model.blocks.first(where: { $0.id == "p1" }) else {
            XCTFail("Expected paragraph block")
            return
        }

        XCTAssertTrue(paragraph.styleTokens.contains { $0.name == "text.color" })
        XCTAssertTrue(paragraph.styleTokens.contains { $0.name == "spacing.after" })
    }

    func testExtensionRenderersHandlePrototypeMatrix() throws {
        let engine = ExtensionNodeTestSupport.makeEngine()

        let model = try engine.render(
            """
            @Callout

            @Tabs {
            - alpha
            - beta
            }

            before <mention userId="alice" /> and <spoiler />
            """,
            parseOptions: .init(documentId: "doc-ext", parseBlockDirectives: true)
        )

        XCTAssertTrue(model.blocks.contains(where: { $0.metadata["extType"] == .string("callout") }))
        XCTAssertTrue(model.blocks.contains(where: { $0.metadata["extType"] == .string("tabs") }))

        let mergedInlines = model.blocks.flatMap(\.inlines)
        XCTAssertTrue(mergedInlines.contains(where: { $0.text.contains("@alice") }))
        XCTAssertTrue(mergedInlines.contains(where: { $0.marks.contains(where: { $0.name == "spoiler" }) }))
    }

    func testUnregisteredExtensionRendererUsesRoleBasedFallback() throws {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: .makeDefault(),
            nodeSpecRegistry: specs
        )
        let engine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: specs),
            renderer: renderer
        )

        let model = try engine.render("before <mention userId=\"u1\" />")
        let spans = model.blocks.flatMap(\.inlines)
        XCTAssertTrue(spans.contains(where: { $0.kind == ExtensionNodeTestSupport.mentionKind }))
        XCTAssertTrue(spans.contains(where: { span in
            span.kind == ExtensionNodeTestSupport.mentionKind
                && span.metadata["sourceKind"] == .string("htmlTag")
        }))
    }

    func testRoleBasedFallbackKeepsExtensionKindForBlockNodes() throws {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: .makeDefault(),
            nodeSpecRegistry: specs
        )
        let engine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: specs),
            renderer: renderer
        )

        let model = try engine.render("@Callout", parseOptions: .init(parseBlockDirectives: true))
        XCTAssertTrue(model.blocks.contains(where: { $0.kind == ExtensionNodeTestSupport.calloutKind }))
    }

    func testRoleBasedFallbackRendersInlineContainerChildren() throws {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: .makeDefault(),
            nodeSpecRegistry: specs
        )
        let engine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: specs),
            renderer: renderer
        )

        let model = try engine.render("before <Cite id=\"r1\">abcdfe</Cite> after")
        let spans = model.blocks.flatMap(\.inlines)
        XCTAssertTrue(spans.contains(where: { $0.text == "abcdfe" }))
    }

    func testStrikethroughProducesStrikethroughMark() throws {
        let model = try MarkdownnAdapter.makeEngine().render("before ~~gone~~ after")
        let spans = model.blocks.flatMap(\.inlines)

        XCTAssertTrue(
            spans.contains(where: { span in
                span.text.contains("gone") && span.marks.contains(where: { $0.name == "strikethrough" })
            })
        )
    }

    func testEngineAcceptsEmptyBlockQuoteAndEmptyListItem() throws {
        let markdown = """
        > 
        
        -
        """

        XCTAssertNoThrow(try MarkdownnAdapter.makeEngine().render(markdown))
    }

    func testTableModelPreservesStructuredCellsAndInlineMarks() throws {
        let model = try MarkdownnAdapter.makeEngine().render(
            """
            | 功能 | 描述 |
            | --- | --- |
            | **加粗标题** | 支持 `代码` 和 [链接](https://example.com) |
            """
        )

        guard let table = model.blocks.first(where: { $0.kind == .table }) else {
            XCTFail("table block missing")
            return
        }
        let head = table.children.first(where: { $0.kind == .tableHead })
        let body = table.children.first(where: { $0.kind == .tableBody })
        XCTAssertNotNil(head)
        XCTAssertNotNil(body)

        guard let firstBodyRow = body?.children.first(where: { $0.kind == .tableRow }),
              let secondCell = firstBodyRow.children.dropFirst().first(where: { $0.kind == .tableCell }) else {
            XCTFail("table row/cell structure missing")
            return
        }

        XCTAssertTrue(secondCell.inlines.contains(where: { $0.kind == .inlineCode && $0.text.contains("代码") }))
        XCTAssertTrue(secondCell.inlines.contains(where: { span in
            span.text.contains("链接") && span.marks.contains(where: { $0.name == "link" })
        }))
    }
}
