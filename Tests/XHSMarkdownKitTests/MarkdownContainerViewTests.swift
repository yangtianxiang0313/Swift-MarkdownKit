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

    func testContainerViewContractDirectiveCustomElementCanOverrideRendering() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerBlockRenderer(forExtension: ExtensionNodeTestSupport.calloutKind.rawValue) { block, _, adapter in
            [adapter.makeTextNode(
                id: block.id,
                kind: "paragraph",
                text: NSAttributedString(string: "CARD_OVERRIDE")
            )]
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

        view.contractRenderAdapter.registerBlockRenderer(forExtension: ExtensionNodeTestSupport.tabsKind.rawValue) { block, _, adapter in
            [adapter.makeTextNode(
                id: block.id,
                kind: "paragraph",
                text: NSAttributedString(string: "BADGE_OVERRIDE")
            )]
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

    func testContainerViewContractStreamingUsesContractAnimationPlanMapper() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let mapper = SpyContractAnimationPlanMapper()
        view.contractAnimationPlanMapper = mapper

        _ = try view.appendContractStreamChunk("hello")

        XCTAssertGreaterThanOrEqual(mapper.callCount, 1)
    }

    func testContainerViewSetContractRenderModelAutoCompilesAnimationPlanUsesMapper() throws {
        let view = makeConfiguredContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let mapper = SpyContractAnimationPlanMapper()
        view.contractAnimationPlanMapper = mapper

        try view.setContractMarkdown("legacy")

        let engine = MarkdownnAdapter.makeEngine()
        let model = try engine.render("# Title")
        view.setContractRenderModel(model)

        XCTAssertGreaterThanOrEqual(mapper.callCount, 1)
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

private final class SpyContractAnimationPlanMapper: ContractAnimationPlanMapping {
    private(set) var callCount: Int = 0

    func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        oldScene: RenderScene,
        newScene: RenderScene,
        diff: SceneDiff,
        defaultEffectKey: AnimationEffectKey
    ) -> AnimationPlan {
        callCount += 1
        return AnimationPlan(steps: [AnimationStep(
            id: "spy.step",
            effectKey: defaultEffectKey,
            entityIDs: diff.changes.map(\.entityId),
            fromScene: oldScene,
            toScene: newScene
        )])
    }
}
