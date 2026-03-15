import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class MarkdownContainerViewTests: XCTestCase {

    func testContainerViewSetContractMarkdownWithoutParserThrowsRequiredFieldMissing() {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        XCTAssertThrowsError(try view.setContractMarkdown("# Title")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.requiredFieldMissing.rawValue)
            XCTAssertEqual(modelError.path, "parserID")
        }
    }

    func testContainerViewContractStreamingWithoutEngineThrowsRequiredFieldMissing() {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        XCTAssertThrowsError(try view.appendContractStreamChunk("Hello")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.requiredFieldMissing.rawValue)
            XCTAssertEqual(modelError.path, "MarkdownContainerView.contractStreamingEngine")
        }
    }

    func testContainerViewSetContractMarkdownProducesContentHeight() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        try view.setContractMarkdown("# Title\n\nParagraph")

        XCTAssertGreaterThan(view.contentHeight, 0)
    }

    func testContainerViewContractStreamingProducesIncrementalUpdates() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let update1 = try view.appendContractStreamChunk("Hello")
        let update2 = try view.appendContractStreamChunk(" world")
        let finalUpdate = try view.finishContractStreaming()

        XCTAssertEqual(update1.sequence, 1)
        XCTAssertEqual(update2.sequence, 2)
        XCTAssertEqual(finalUpdate.sequence, 3)
        XCTAssertTrue(finalUpdate.isFinal)
        XCTAssertGreaterThan(view.contentHeight, 0)
    }

    func testContainerViewContractStreamingCoversCustomInlineAndSpecialFormats() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerInlineRenderer(forExtension: ExtensionNodeTestSupport.mentionKind.rawValue) { span, _, _, _ in
            let userID = span.contractAttrString(for: "userId") ?? "unknown"
            return NSAttributedString(string: "[mention:\(userID)]")
        }
        view.contractRenderAdapter.registerInlineRenderer(forExtension: ExtensionNodeTestSupport.citeKind.rawValue) { span, _, _, _ in
            NSAttributedString(string: "[cite:\(span.text)]")
        }

        let first = try view.appendContractStreamChunk("before <mention userId=\"u1\" /> and ")
        let second = try view.appendContractStreamChunk("<Cite id=\"ref-1\">ref-1</Cite>\n\n")
        let third = try view.appendContractStreamChunk("```swift\nprint(1)\n```\n\n|k|v|\n|---|---|\n|a|b|\n\n~~gone~~")
        let final = try view.finishContractStreaming()

        XCTAssertEqual([first.sequence, second.sequence, third.sequence, final.sequence], [1, 2, 3, 4])
        XCTAssertTrue(final.isFinal)
        XCTAssertTrue(final.model.blocks.contains(where: { $0.kind == .codeBlock }))
        XCTAssertTrue(final.model.blocks.contains(where: { $0.kind == .table }))

        let renderedText = mergedText(from: view.currentSceneSnapshot)
        XCTAssertTrue(renderedText.contains("[mention:u1]"))
        XCTAssertTrue(renderedText.contains("ref-1"))
        XCTAssertTrue(renderedText.contains("gone"))
        XCTAssertTrue(flatten(final.document.root).contains(where: { $0.kind == ExtensionNodeTestSupport.citeKind }))
    }

    func testContainerViewContractDirectiveCustomElementCanOverrideRendering() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerBlockMapper(forExtension: ExtensionNodeTestSupport.calloutKind.rawValue) { block, _, adapter in
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "paragraph",
                attributedText: NSAttributedString(string: "CARD_OVERRIDE")
            )
            return [.mergeSegment(segment)]
        }

        let rewrite = MarkdownContract.CanonicalRewritePipeline(
            nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry()
        )
        try view.setContractMarkdown(
            """
            @Callout
            """,
            rewritePipeline: rewrite
        )

        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).contains("CARD_OVERRIDE"))
    }

    func testContainerViewContractHTMLCustomElementCanOverrideRendering() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerBlockMapper(forExtension: ExtensionNodeTestSupport.tabsKind.rawValue) { block, _, adapter in
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "paragraph",
                attributedText: NSAttributedString(string: "BADGE_OVERRIDE")
            )
            return [.mergeSegment(segment)]
        }

        let rewrite = MarkdownContract.CanonicalRewritePipeline(
            nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry()
        )
        try view.setContractMarkdown(
            """
            @Tabs {
            body
            }
            """,
            rewritePipeline: rewrite
        )

        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).contains("BADGE_OVERRIDE"))
    }

    func testContainerViewContractInlineHTMLCustomElementCanOverrideRendering() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerInlineRenderer(forExtension: ExtensionNodeTestSupport.mentionKind.rawValue) { _, _, _, _ in
            NSAttributedString(string: "[INLINE_BADGE]")
        }

        let rewrite = MarkdownContract.CanonicalRewritePipeline(
            nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry()
        )
        try view.setContractMarkdown(
            "before <mention userId=\"new\" /> after",
            rewritePipeline: rewrite
        )

        let text = mergedText(from: view.currentSceneSnapshot)
        XCTAssertTrue(text.contains("before"))
        XCTAssertTrue(text.contains("[INLINE_BADGE]"))
        XCTAssertTrue(text.contains("after"))
    }

    func testContainerViewStreamingUsesQueueByDefault() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        XCTAssertEqual(view.animationConcurrencyPolicy, .fullyOrdered)
    }

    func testContainerViewSubmissionModeMapsToConcurrencyPolicy() {
        let view = makeConfiguredContainerView()
        view.animationSubmissionMode = .queueLatest
        XCTAssertEqual(view.animationConcurrencyPolicy, .fullyOrdered)

        view.animationSubmissionMode = .interruptCurrent
        XCTAssertEqual(view.animationConcurrencyPolicy, .latestWins)
    }

    private func makeConfiguredContainerView() -> MarkdownContainerView {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: ExtensionNodeTestSupport.makeRendererRegistry(),
            nodeSpecRegistry: specs
        )

        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        registry.registerParser(parser, id: MarkdownnAdapter.parserID)
        registry.registerRenderer(renderer, id: MarkdownnAdapter.rendererID)

        let streamingEngine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: specs),
            renderer: renderer
        )

        return MarkdownContainerView(
            theme: .default,
            contractKit: MarkdownContract.UniversalMarkdownKit(registry: registry),
            contractStreamingEngine: streamingEngine
        )
    }
}

private extension MarkdownContainerViewTests {
    func flatten(_ root: MarkdownContract.CanonicalNode) -> [MarkdownContract.CanonicalNode] {
        var result: [MarkdownContract.CanonicalNode] = [root]
        for child in root.children {
            result.append(contentsOf: flatten(child))
        }
        return result
    }
}
