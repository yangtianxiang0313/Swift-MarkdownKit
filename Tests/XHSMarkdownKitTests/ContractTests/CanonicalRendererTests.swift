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
        registry.registerBlockRenderer(for: "heading") { node, _, _ in
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

    func testInlineHTMLCustomElementRendersAsCustomInlineSpan() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("Hello <badge text=\"new\" /> world")

        guard let paragraph = model.blocks.first(where: { $0.kind == .paragraph }) else {
            XCTFail("Expected paragraph block")
            return
        }

        let customSpan = paragraph.inlines.first(where: { $0.kind == .custom })
        XCTAssertNotNil(customSpan)

        if case let .object(attrs)? = customSpan?.metadata["attrs"] {
            XCTAssertEqual(attrs["customType"], .string("htmlTag"))
        } else {
            XCTFail("Expected attrs metadata on custom span")
        }
    }

    func testRendererCollectsImageAssets() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("![alt](https://example.com/image.png)")

        XCTAssertTrue(model.blocks.contains(where: { $0.kind == .image }))
        XCTAssertTrue(model.assets.contains(where: { $0.type == "image" && $0.source == "https://example.com/image.png" }))
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

    func testCustomElementInheritsParentStyleAndAppliesNamedRule() throws {
        let root = MarkdownContract.CanonicalNode(
            id: "root",
            kind: .document,
            children: [
                MarkdownContract.CanonicalNode(
                    id: "card-1",
                    kind: .customElement,
                    attrs: [
                        "name": .string("Card"),
                        "customType": .string("directive")
                    ],
                    source: .init(sourceKind: .directive)
                )
            ],
            source: .init(sourceKind: .markdown)
        )
        let document = MarkdownContract.CanonicalDocument(documentId: "inherit-doc", root: root)

        let options = MarkdownContract.CanonicalRenderOptions(
            nodeStyleSheet: .init(
                byNodeKind: [
                    "document": .init(
                        inheritFromParent: false,
                        styleTokens: [.init(name: "text.color", value: .string("base"))]
                    ),
                    "customElement": .init(inheritFromParent: true)
                ],
                byCustomElementName: [
                    "Card": .init(
                        inheritFromParent: true,
                        styleTokens: [.init(name: "card.radius", value: .number(8))]
                    )
                ]
            )
        )

        let model = try MarkdownContract.DefaultCanonicalRenderer().render(document: document, options: options)
        guard let card = model.blocks.first(where: { $0.id == "card-1" }) else {
            XCTFail("Expected custom card block")
            return
        }

        XCTAssertTrue(card.styleTokens.contains { $0.name == "text.color" })
        XCTAssertTrue(card.styleTokens.contains { $0.name == "card.radius" })
    }

    func testNamedCustomElementRendererOverridesDefaultCustomElementRendering() throws {
        let registry = MarkdownContract.CanonicalRendererRegistry.makeDefault()
        registry.registerCustomElementBlockRenderer(named: "Card") { node, _, _ in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: .custom,
                styleTokens: [],
                metadata: ["renderer": .string("named-card")]
            )]
        }

        let engine = MarkdownContractEngine(
            parser: XYMarkdownContractParser(),
            renderer: MarkdownContract.DefaultCanonicalRenderer(registry: registry)
        )
        let model = try engine.render("@Card {\\nHello\\n}")

        XCTAssertTrue(model.blocks.contains(where: { $0.metadata["renderer"] == .string("named-card") }))
    }
}
