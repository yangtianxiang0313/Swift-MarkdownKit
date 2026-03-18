import XCTest
import UIKit
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class RenderModelUIKitAdapterTests: XCTestCase {

    func testAdapterFailsWhenBlockMapperChainIsEmpty() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("plain")

        let adapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.BlockMapperChain()
        )

        XCTAssertThrowsError(try adapter.render(model: model, theme: .default, maxWidth: 320)) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.requiredFieldMissing.rawValue)
        }
    }

    func testAdapterMergesHeadingAndParagraphIntoMergedTextNode() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("# Title\n\nBody")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        let nodes = scene.flattenRenderableNodes()
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.kind, "mergedText")
        XCTAssertTrue(nodes.first?.component is MergedTextSceneComponent)
        XCTAssertTrue(mergedText(from: scene).contains("Title"))
        XCTAssertTrue(mergedText(from: scene).contains("Body"))
    }

    func testAdapterAllowsOverridingStandardBlockMapper() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("# Title")

        let adapter = makeAdapter()
        adapter.registerBlockMapper(for: .heading) { block, _, adapter in
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "heading",
                attributedText: NSAttributedString(string: "OVERRIDE"),
                spacingAfter: 0
            )
            return [.mergeSegment(segment)]
        }

        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        XCTAssertEqual(mergedText(from: scene).trimmingCharacters(in: .whitespacesAndNewlines), "OVERRIDE")
    }

    func testAdapterAllowsOverridingInlineCustomElementRenderer() throws {
        let engine = ExtensionNodeTestSupport.makeEngine()
        let model = try engine.render("before <mention userId=\"badge\" /> after")

        let adapter = makeAdapter()
        adapter.registerInlineRenderer(forExtension: ExtensionNodeTestSupport.mentionKind.rawValue) { _, _, _, _ in
            NSAttributedString(string: "[BADGE]")
        }

        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        let text = mergedText(from: scene)

        XCTAssertTrue(text.contains("before"))
        XCTAssertTrue(text.contains("[BADGE]"))
        XCTAssertTrue(text.contains("after"))
    }

    func testAdapterUsesMergedTextAndStandaloneComponents() throws {
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

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        let nodes = scene.flattenRenderableNodes()
        XCTAssertTrue(nodes.contains(where: {
            $0.kind == "mergedText" && $0.component is MergedTextSceneComponent
        }))
        XCTAssertTrue(nodes.contains(where: {
            $0.kind == "codeBlock" && $0.component is CodeBlockSceneComponent
        }))
        XCTAssertTrue(nodes.contains(where: {
            $0.kind == "thematicBreak" && $0.component is RuleSceneComponent
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

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        let text = mergedText(from: scene)

        XCTAssertTrue(text.contains("3. third"))
        XCTAssertTrue(text.contains("4. fourth"))
    }

    func testBlockQuoteKeepsDepthAttributesInMergedText() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            > level-1
            > > level-2
            """
        )

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let mergedNode = scene.flattenRenderableNodes().first(where: { $0.component is MergedTextSceneComponent }),
              let component = mergedNode.component as? MergedTextSceneComponent else {
            XCTFail("merged text node missing")
            return
        }

        let text = component.attributedText.string
        XCTAssertTrue(text.contains("level-1"))
        XCTAssertTrue(text.contains("level-2"))

        let range = NSRange(location: 0, length: component.attributedText.length)
        var foundQuoteDepth = false
        component.attributedText.enumerateAttribute(.xhsBlockQuoteDepth, in: range, options: []) { value, _, stop in
            if let depth = value as? Int, depth > 0 {
                foundQuoteDepth = true
                stop.pointee = true
            }
        }
        XCTAssertTrue(foundQuoteDepth)
    }

    func testBlockQuoteDepthDoesNotLeakIntoNonQuoteParagraph() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            > quoted

            plain
            """
        )

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let mergedNode = scene.flattenRenderableNodes().first(where: { $0.component is MergedTextSceneComponent }),
              let component = mergedNode.component as? MergedTextSceneComponent else {
            XCTFail("merged text node missing")
            return
        }

        let text = component.attributedText.string as NSString
        let quoteRange = text.range(of: "quoted")
        let plainRange = text.range(of: "plain")
        XCTAssertNotEqual(quoteRange.location, NSNotFound)
        XCTAssertNotEqual(plainRange.location, NSNotFound)

        XCTAssertGreaterThan(maxQuoteDepth(in: component.attributedText, range: quoteRange), 0)
        XCTAssertEqual(maxQuoteDepth(in: component.attributedText, range: plainRange), 0)
    }

    func testBlockQuoteAppliesParagraphLeadingIndent() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("> quoted")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let mergedNode = scene.flattenRenderableNodes().first(where: { $0.component is MergedTextSceneComponent }),
              let component = mergedNode.component as? MergedTextSceneComponent else {
            XCTFail("merged text node missing")
            return
        }

        let text = component.attributedText.string as NSString
        let quoteRange = text.range(of: "quoted")
        XCTAssertNotEqual(quoteRange.location, NSNotFound)

        guard let paragraph = component.attributedText.attribute(.paragraphStyle, at: quoteRange.location, effectiveRange: nil) as? NSParagraphStyle else {
            XCTFail("paragraph style missing")
            return
        }

        XCTAssertGreaterThan(paragraph.firstLineHeadIndent, 0)
        XCTAssertEqual(paragraph.firstLineHeadIndent, paragraph.headIndent, accuracy: 0.001)
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

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

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

    func testTableCellResolvesInlineStyles() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render(
            """
            | 功能 | 描述 |
            | --- | --- |
            | **加粗标题** | 支持 `代码` 和 [链接](https://example.com) |
            """
        )

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let tableNode = scene.flattenRenderableNodes().first(where: { $0.kind == "table" }),
              let tableComponent = tableNode.component as? TableSceneComponent else {
            XCTFail("table scene component missing")
            return
        }
        XCTAssertEqual(tableComponent.rows.count, 1)
        XCTAssertEqual(tableComponent.rows[0].count, 2)

        let titleCell = tableComponent.rows[0][0]
        let titleText = titleCell.string as NSString
        let titleRange = titleText.range(of: "加粗标题")
        XCTAssertNotEqual(titleRange.location, NSNotFound)
        let titleFont = titleCell.attribute(.font, at: titleRange.location, effectiveRange: nil) as? UIFont
        XCTAssertEqual(titleFont?.isBold, true)

        let descCell = tableComponent.rows[0][1]
        let descText = descCell.string as NSString
        let codeRange = descText.range(of: "代码")
        XCTAssertNotEqual(codeRange.location, NSNotFound)
        let codeFont = descCell.attribute(.font, at: codeRange.location, effectiveRange: nil) as? UIFont
        XCTAssertEqual(codeFont?.isMonospace, true)

        let linkRange = descText.range(of: "链接")
        XCTAssertNotEqual(linkRange.location, NSNotFound)
        let linkValue = descCell.attribute(.link, at: linkRange.location, effectiveRange: nil) as? String
        XCTAssertEqual(linkValue, "https://example.com")
    }

    func testInlineCodeCanCombineWithStrongMark() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("**`代码`**")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let mergedNode = scene.flattenRenderableNodes().first(where: { $0.component is MergedTextSceneComponent }),
              let component = mergedNode.component as? MergedTextSceneComponent else {
            XCTFail("merged text node missing")
            return
        }

        let text = component.attributedText.string as NSString
        let codeRange = text.range(of: "代码")
        XCTAssertNotEqual(codeRange.location, NSNotFound)
        let font = component.attributedText.attribute(.font, at: codeRange.location, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.isMonospace, true)
        XCTAssertEqual(font?.isBold, true)
    }

    func testLinkInlineCarriesInteractionAnchorAttributes() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("[OpenAI](https://openai.com)")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let mergedNode = scene.flattenRenderableNodes().first(where: { $0.component is MergedTextSceneComponent }),
              let component = mergedNode.component as? MergedTextSceneComponent else {
            XCTFail("merged text node missing")
            return
        }

        let text = component.attributedText.string as NSString
        let linkRange = text.range(of: "OpenAI")
        XCTAssertNotEqual(linkRange.location, NSNotFound)

        let nodeID = component.attributedText.attribute(
            .xhsInteractionNodeID,
            at: linkRange.location,
            effectiveRange: nil
        ) as? String
        let nodeKind = component.attributedText.attribute(
            .xhsInteractionNodeKind,
            at: linkRange.location,
            effectiveRange: nil
        ) as? String
        let url = component.attributedText.attribute(
            .link,
            at: linkRange.location,
            effectiveRange: nil
        ) as? String

        XCTAssertNotNil(nodeID)
        XCTAssertEqual(nodeKind, MarkdownContract.InlineKind.link.rawValue)
        XCTAssertEqual(url, "https://openai.com")
    }

    func testThematicBreakViewHasBoundedHeight() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("---")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let ruleNode = scene.flattenRenderableNodes().first(where: { $0.kind == "thematicBreak" }),
              let ruleComponent = ruleNode.component as? RuleSceneComponent else {
            XCTFail("thematicBreak scene component missing")
            return
        }

        let view = ruleComponent.makeView()
        ruleComponent.configure(view: view, maxWidth: 320)
        let fitted = view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        let expected = ruleComponent.height + ruleComponent.verticalPadding * 2

        XCTAssertTrue(fitted.height.isFinite)
        XCTAssertEqual(fitted.height, expected, accuracy: 0.001)
        XCTAssertLessThan(fitted.height, 200)
    }

    func testBlockQuoteThematicBreakAppliesLeadingInset() throws {
        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("> ---")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let ruleNode = scene.flattenRenderableNodes().first(where: { $0.kind == "thematicBreak" }),
              let ruleComponent = ruleNode.component as? RuleSceneComponent else {
            XCTFail("thematicBreak scene component missing")
            return
        }

        XCTAssertGreaterThan(ruleComponent.leadingInset, 0)
    }

    func testListItemChildThematicBreakUsesMarkerContentIndent() throws {
        let model = MarkdownContract.RenderModel(
            documentId: "doc-list-rule",
            blocks: [
                MarkdownContract.RenderBlock(
                    id: "list-1",
                    kind: .list,
                    children: [
                        MarkdownContract.RenderBlock(
                            id: "item-1",
                            kind: .listItem,
                            children: [
                                MarkdownContract.RenderBlock(
                                    id: "p-1",
                                    kind: .paragraph,
                                    inlines: [
                                        MarkdownContract.InlineSpan(id: "t-1", kind: .text, text: "item")
                                    ]
                                ),
                                MarkdownContract.RenderBlock(
                                    id: "hr-1",
                                    kind: .thematicBreak
                                )
                            ]
                        )
                    ],
                    metadata: [
                        "attrs": .object([
                            "ordered": .bool(false),
                            "startIndex": .int(1)
                        ])
                    ]
                )
            ]
        )

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

        guard let ruleNode = scene.flattenRenderableNodes().first(where: { $0.id == "hr-1" }),
              let ruleComponent = ruleNode.component as? RuleSceneComponent else {
            XCTFail("list item thematicBreak scene component missing")
            return
        }

        XCTAssertGreaterThan(ruleComponent.leadingInset, 0)
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

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)

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

    func testCustomStandaloneNodeReceivesRevealStateWithoutRevealClosure() {
        let adapter = makeAdapter()
        let descriptor = adapter.makeCustomStandaloneNode(
            id: "custom.reveal.card",
            kind: "custom.card",
            reuseIdentifier: "custom.card",
            signature: "v1",
            revealUnitCount: 24,
            makeView: { RevealHeightProbeView() },
            configure: { view, maxWidth in
                (view as? RevealHeightProbeView)?.configure(maxWidth: maxWidth)
            }
        )

        guard let component = descriptor.component as? any RevealAnimatableComponent else {
            XCTFail("Expected reveal animatable component")
            return
        }

        let view = component.makeView()
        component.configure(view: view, maxWidth: 320)
        component.reveal(
            view: view,
            state: RevealState(
                displayedUnits: 2,
                totalUnits: 24,
                stableUnits: 2,
                elapsedMilliseconds: 10
            )
        )
        let earlyHeight = view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height

        component.reveal(
            view: view,
            state: RevealState(
                displayedUnits: 20,
                totalUnits: 24,
                stableUnits: 20,
                elapsedMilliseconds: 80
            )
        )
        let laterHeight = view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height

        XCTAssertGreaterThan(laterHeight, earlyHeight)
    }

    func testCodeBlockReadsCopyStatusFromProjectedUIState() throws {
        let model = MarkdownContract.RenderModel(
            documentId: "doc-code-status",
            blocks: [
                MarkdownContract.RenderBlock(
                    id: "code-1",
                    kind: .codeBlock,
                    metadata: [
                        "code": .string("print(1)"),
                        "uiState": .object(["copyStatus": .string("copied")])
                    ]
                )
            ]
        )

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        guard let codeNode = scene.flattenRenderableNodes().first(where: { $0.id == "code-1" }),
              let component = codeNode.component as? CodeBlockSceneComponent else {
            XCTFail("codeBlock component missing")
            return
        }

        XCTAssertEqual(component.copyStatus, "copied")
    }

    func testAdapterUsesDefaultFallbackForExtensionBlockWithoutCustomMapper() throws {
        let engine = ExtensionNodeTestSupport.makeEngine()
        let model = try engine.render("@Callout")

        let adapter = makeAdapter()
        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        XCTAssertTrue(mergedText(from: scene).contains("[CALLOUT]"))
    }

    private func makeAdapter() -> MarkdownContract.RenderModelUIKitAdapter {
        MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )
    }

    private func maxQuoteDepth(in attributedText: NSAttributedString, range: NSRange) -> Int {
        guard range.location != NSNotFound, range.length > 0 else { return 0 }
        var result = 0
        attributedText.enumerateAttribute(.xhsBlockQuoteDepth, in: range, options: []) { value, _, _ in
            let depth = max(0, value as? Int ?? 0)
            result = max(result, depth)
        }
        return result
    }
}

private final class RevealHeightProbeView: UIView, RevealLayoutAnimatableView {
    private var configuredMaxWidth: CGFloat = 0
    private var revealedUnits: Int = 0

    func configure(maxWidth: CGFloat) {
        configuredMaxWidth = max(1, maxWidth)
    }

    func applyRevealState(_ state: RevealState) {
        revealedUnits = max(0, state.displayedUnits)
        invalidateRevealLayout()
    }

    override var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: configuredMaxWidth, height: CGFloat.greatestFiniteMagnitude))
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = max(1, size.width > 0 ? size.width : configuredMaxWidth)
        let height = CGFloat(max(1, revealedUnits)) * 4 + 8
        return CGSize(width: width, height: height)
    }
}
