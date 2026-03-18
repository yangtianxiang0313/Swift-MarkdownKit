import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

@MainActor
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

    func testContainerViewSetContractMarkdownProducesContentHeight() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        try view.setContractMarkdown("# Title\n\nParagraph")

        XCTAssertGreaterThan(view.contentHeight, 0)
    }

    func testRuntimeStreamingProducesIncrementalUpdatesOnContainer() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        let runtime = makeConfiguredRuntime()
        runtime.attach(to: view)

        let ref = try runtime.startStream(documentID: "doc.runtime.stream.1")
        try runtime.appendStreamChunk(ref: ref, chunk: "Hello")
        try runtime.appendStreamChunk(ref: ref, chunk: " world")
        try runtime.finishStream(ref: ref)

        let renderedText = mergedText(from: view.currentSceneSnapshot)
        XCTAssertTrue(renderedText.contains("Hello world"))
        XCTAssertGreaterThan(view.contentHeight, 0)
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

    func testContainerViewDefaultAppearanceModeIsSequential() {
        let view = makeConfiguredContainerView()
        XCTAssertEqual(view.contentEntityAppearanceMode, .sequential)
    }

    func testContainerViewRenderFailureKeepsPreviousSceneAndReportsError() {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        let delegate = RenderFailureDelegateSpy()
        view.delegate = delegate

        let initialModel = makeRenderModel(documentID: "doc.failure", text: "Before")
        view.setContractRenderModel(initialModel)
        let beforeScene = view.currentSceneSnapshot
        let beforeHeight = view.contentHeight

        let failingAdapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.BlockMapperChain()
        )
        view.contractRenderAdapter = failingAdapter

        let failingModel = makeRenderModel(documentID: "doc.failure", text: "After")
        view.setContractRenderModel(failingModel)

        XCTAssertEqual(view.currentSceneSnapshot, beforeScene)
        XCTAssertEqual(view.contentHeight, beforeHeight)
        XCTAssertNotNil(view.lastRenderError)
        XCTAssertEqual(delegate.failureDocumentIDs, ["doc.failure"])
        XCTAssertEqual(delegate.failureCount, 1)
    }

    func testContainerViewCanRecoverAfterRenderFailure() {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        let delegate = RenderFailureDelegateSpy()
        view.delegate = delegate

        let initialModel = makeRenderModel(documentID: "doc.recover", text: "Initial")
        view.setContractRenderModel(initialModel)

        let failingAdapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.BlockMapperChain()
        )
        view.contractRenderAdapter = failingAdapter
        view.setContractRenderModel(makeRenderModel(documentID: "doc.recover", text: "ShouldFail"))

        XCTAssertNotNil(view.lastRenderError)
        XCTAssertEqual(delegate.failureCount, 1)

        view.contractRenderAdapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )
        view.setContractRenderModel(makeRenderModel(documentID: "doc.recover", text: "Recovered"))

        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).contains("Recovered"))
        XCTAssertNil(view.lastRenderError)
        XCTAssertEqual(delegate.failureCount, 1)
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

        return MarkdownContainerView(
            theme: .default,
            contractKit: MarkdownContract.UniversalMarkdownKit(registry: registry)
        )
    }

    private func makeConfiguredRuntime() -> MarkdownRuntime {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: ExtensionNodeTestSupport.makeRendererRegistry(),
            nodeSpecRegistry: specs
        )
        let streamingEngine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: specs),
            renderer: renderer
        )

        return MarkdownRuntime(streamingEngine: streamingEngine)
    }

    private func makeRenderModel(documentID: String, text: String) -> MarkdownContract.RenderModel {
        MarkdownContract.RenderModel(
            documentId: documentID,
            blocks: [
                .init(
                    id: "\(documentID).paragraph",
                    kind: .paragraph,
                    inlines: [.init(id: "\(documentID).text", kind: .text, text: text)]
                )
            ]
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

private final class RenderFailureDelegateSpy: MarkdownContainerViewDelegate {
    private(set) var failureDocumentIDs: [String] = []
    private(set) var failureCount: Int = 0

    func containerView(_ view: MarkdownContainerView, didFailRender error: Error, forDocumentID documentID: String) {
        failureCount += 1
        failureDocumentIDs.append(documentID)
    }
}
