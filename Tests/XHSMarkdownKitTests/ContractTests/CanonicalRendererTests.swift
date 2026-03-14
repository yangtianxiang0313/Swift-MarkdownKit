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

    func testUnregisteredExtensionRendererFails() throws {
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

        XCTAssertThrowsError(try engine.render("before <mention userId=\"u1\" />")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                return XCTFail("Expected ModelError")
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.unknownNodeKind.rawValue)
        }
    }
}
