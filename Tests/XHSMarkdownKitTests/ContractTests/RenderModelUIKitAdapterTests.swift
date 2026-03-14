import XCTest
import UIKit
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class RenderModelUIKitAdapterTests: XCTestCase {

    func testAdapterRendersHeadingAndParagraphSceneNodes() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("# Title\n\nBody")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(
            model: model,
            theme: .default,
            maxWidth: 320
        )

        let nodes = scene.flattenRenderableNodes()
        XCTAssertTrue(nodes.contains(where: { $0.kind == "heading" }))
        XCTAssertTrue(nodes.contains(where: { $0.kind == "paragraph" }))
        XCTAssertTrue(mergedText(from: scene).contains("Title"))
        XCTAssertTrue(mergedText(from: scene).contains("Body"))
    }

    func testAdapterAllowsOverridingStandardBlockRenderer() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("# Title")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerBlockRenderer(for: .heading) { block, _, adapter in
            [adapter.makeTextNode(
                id: block.id,
                kind: "heading",
                text: NSAttributedString(string: "OVERRIDE")
            )]
        }

        let scene = adapter.render(
            model: model,
            theme: .default,
            maxWidth: 320
        )

        XCTAssertEqual(mergedText(from: scene).trimmingCharacters(in: .whitespacesAndNewlines), "OVERRIDE")
    }

    func testAdapterAllowsOverridingInlineCustomElementRenderer() throws {
        let engine = ExtensionNodeTestSupport.makeEngine()
        let model = try engine.render("before <mention userId=\"badge\" /> after")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerInlineRenderer(forExtension: ExtensionNodeTestSupport.mentionKind.rawValue) { _, _, _, _ in
            NSAttributedString(string: "[BADGE]")
        }

        let scene = adapter.render(
            model: model,
            theme: .default,
            maxWidth: 320
        )
        let text = mergedText(from: scene)

        XCTAssertTrue(text.contains("before"))
        XCTAssertTrue(text.contains("[BADGE]"))
        XCTAssertTrue(text.contains("after"))
        XCTAssertFalse(text.contains("mention"))
    }

    func testAdapterUsesSceneComponentsByDefault() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            # Title

            > quote

            ```swift
            print("hi")
            ```

            ---
            """
        )

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)

        let nodes = scene.flattenRenderableNodes()
        XCTAssertTrue(nodes.contains(where: {
            $0.kind == "heading" && $0.component is TextSceneComponent
        }))
        XCTAssertTrue(nodes.contains(where: {
            $0.kind == "codeBlock" && $0.component is CodeBlockSceneComponent
        }))
        XCTAssertTrue(nodes.contains(where: {
            $0.kind == "thematicBreak" && $0.component is RuleSceneComponent
        }))
        XCTAssertTrue(scene.nodes.contains(where: {
            $0.kind == "blockQuote" && !$0.children.isEmpty
        }))
    }

    func testOrderedListHonorsStartIndex() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            3. third
            4. fourth
            """
        )

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)
        let text = mergedText(from: scene)

        XCTAssertTrue(text.contains("3. third"))
        XCTAssertTrue(text.contains("4. fourth"))
    }

    func testBlockQuoteUsesContainerComponent() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("> quoted text")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)
        let blockQuote = scene.nodes.first { $0.kind == "blockQuote" }
        let quoteParagraph = blockQuote?.children.first { $0.kind == "paragraph" }

        XCTAssertNotNil(blockQuote)
        XCTAssertTrue(blockQuote?.component is BlockQuoteContainerSceneComponent)
        XCTAssertNotNil(quoteParagraph)
        XCTAssertTrue(quoteParagraph?.component is TextSceneComponent)
    }

    func testNestedBlockQuoteProducesNestedContainerNodes() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            > level-1
            > > level-2
            > > still-level-2
            > back-level-1
            """
        )

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let outerQuote = scene.nodes.first(where: { $0.kind == "blockQuote" }) else {
            XCTFail("outer blockQuote not found")
            return
        }
        XCTAssertTrue(outerQuote.component is BlockQuoteContainerSceneComponent)

        let nestedQuote = outerQuote.children.first(where: { $0.kind == "blockQuote" })
        XCTAssertNotNil(nestedQuote)
        XCTAssertTrue(nestedQuote?.component is BlockQuoteContainerSceneComponent)

        let merged = mergedText(from: scene)
        XCTAssertTrue(merged.contains("level-1"))
        XCTAssertTrue(merged.contains("level-2"))
        XCTAssertTrue(merged.contains("back-level-1"))
    }

    func testTableUsesDedicatedTableSceneComponent() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            | name | age |
            | :--- | ---:|
            | tom  | 10  |
            | bob  | 12  |
            """
        )

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let tableNode = scene.flattenRenderableNodes().first(where: { $0.kind == "table" }) else {
            XCTFail("table scene node not found")
            return
        }

        guard let tableComponent = tableNode.component as? TableSceneComponent else {
            XCTFail("table node does not use TableSceneComponent")
            return
        }

        XCTAssertEqual(tableComponent.headers.count, 2)
        XCTAssertEqual(tableComponent.rows.count, 2)
        XCTAssertEqual(tableComponent.alignments, [.left, .right])
    }

    func testCodeBlockViewProvidesPositiveIntrinsicHeight() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            ```swift
            let a = 1
            let b = 2
            print(a + b)
            ```
            """
        )

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let codeNode = scene.flattenRenderableNodes().first(where: { $0.kind == "codeBlock" }) else {
            XCTFail("codeBlock scene node not found")
            return
        }

        guard let codeComponent = codeNode.component else {
            XCTFail("codeBlock component missing")
            return
        }

        let view = codeComponent.makeView()
        codeComponent.configure(view: view, maxWidth: 320)
        let height = view.intrinsicContentSize.height
        XCTAssertTrue(height > 0, "expected positive intrinsic height, got \(height)")
    }

    func testCodeBlockUsesBlockTextColorFromTheme() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            ```swift
            print("theme")
            ```
            """
        )

        var theme = MarkdownTheme.default
        theme.code.block.textColor = .systemRed

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: theme, maxWidth: 320)

        guard let codeNode = scene.flattenRenderableNodes().first(where: { $0.kind == "codeBlock" }) else {
            XCTFail("codeBlock scene node not found")
            return
        }
        guard let codeComponent = codeNode.component as? CodeBlockSceneComponent else {
            XCTFail("codeBlock component missing")
            return
        }

        XCTAssertEqual(codeComponent.textColor, .systemRed)
    }

    func testTableAlignmentsPreserveNilSlots() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            | a | b | c |
            | :-- | --- | --: |
            | 1 | 2 | 3 |
            """
        )

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let scene = adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let tableNode = scene.flattenRenderableNodes().first(where: { $0.kind == "table" }) else {
            XCTFail("table scene node not found")
            return
        }
        guard let tableComponent = tableNode.component as? TableSceneComponent else {
            XCTFail("table node does not use TableSceneComponent")
            return
        }

        XCTAssertEqual(tableComponent.alignments, [.left, .left, .right])
    }

    func testTableViewHeightExpandsForLongWrappedCell() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.label
        ]
        let header = NSAttributedString(string: "Content", attributes: attributes)
        let shortCell = NSAttributedString(string: "short", attributes: attributes)
        let longCell = NSAttributedString(
            string: "This is a long table cell that should wrap into multiple lines under constrained width.",
            attributes: attributes
        )

        let shortComponent = TableSceneComponent(
            headers: [header],
            rows: [[shortCell]],
            alignments: [.left],
            headerBackgroundColor: .secondarySystemBackground,
            borderColor: .separator,
            cornerRadius: 8,
            cellPadding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        )
        let longComponent = TableSceneComponent(
            headers: [header],
            rows: [[longCell]],
            alignments: [.left],
            headerBackgroundColor: .secondarySystemBackground,
            borderColor: .separator,
            cornerRadius: 8,
            cellPadding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        )

        let shortView = shortComponent.makeView()
        shortComponent.configure(view: shortView, maxWidth: 220)
        let shortHeight = shortView.intrinsicContentSize.height

        let longView = longComponent.makeView()
        longComponent.configure(view: longView, maxWidth: 220)
        let longHeight = longView.intrinsicContentSize.height

        XCTAssertGreaterThan(longHeight, shortHeight + 10)
    }
}
