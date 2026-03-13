import XCTest
@testable import XHSMarkdownKit

final class MarkdownContainerViewTests: XCTestCase {

    func testContainerViewSetContractMarkdownProducesContentHeight() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        try view.setContractMarkdown("# Title\n\nParagraph")

        XCTAssertGreaterThan(view.contentHeight, 0)
    }

    func testContainerViewContractStreamingProducesIncrementalUpdates() throws {
        let view = MarkdownContainerView(theme: .default)
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
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerBlockRenderer(forCustomElement: "Card") { block, context, _ in
            let attributed = NSAttributedString(string: "CARD_OVERRIDE")
            let fragmentContext = context.makeFragmentContext()

            return [ContractTextFragment(
                fragmentId: block.id,
                nodeType: .paragraph,
                reuseIdentifier: .contractTextView,
                context: fragmentContext,
                attributedString: attributed,
                makeView: { ContractTextView() },
                configure: { view, _ in
                    guard let textView = view as? ContractTextView else { return }
                    textView.configure(attributedString: attributed, indent: fragmentContext[IndentKey.self])
                }
            )]
        }

        try view.setContractMarkdown(
            """
            @Card(title: "hero") {
            Hello
            }
            """
        )

        XCTAssertTrue(mergedText(from: view.fragments).contains("CARD_OVERRIDE"))
    }

    func testContainerViewContractHTMLCustomElementCanOverrideRendering() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerBlockRenderer(forCustomElement: "badge") { block, context, _ in
            let attributed = NSAttributedString(string: "BADGE_OVERRIDE")
            let fragmentContext = context.makeFragmentContext()

            return [ContractTextFragment(
                fragmentId: block.id,
                nodeType: .paragraph,
                reuseIdentifier: .contractTextView,
                context: fragmentContext,
                attributedString: attributed,
                makeView: { ContractTextView() },
                configure: { view, _ in
                    guard let textView = view as? ContractTextView else { return }
                    textView.configure(attributedString: attributed, indent: fragmentContext[IndentKey.self])
                }
            )]
        }

        try view.setContractMarkdown(
            """
            <badge text="new">
            body
            </badge>
            """
        )

        XCTAssertTrue(mergedText(from: view.fragments).contains("BADGE_OVERRIDE"))
    }

    func testContainerViewContractInlineHTMLCustomElementCanOverrideRendering() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.contractRenderAdapter.registerInlineRenderer(forCustomElement: "badge") { _, _, _, _ in
            NSAttributedString(string: "[INLINE_BADGE]")
        }

        try view.setContractMarkdown("before <badge text=\"new\" /> after")

        let text = mergedText(from: view.fragments)
        XCTAssertTrue(text.contains("before"))
        XCTAssertTrue(text.contains("[INLINE_BADGE]"))
        XCTAssertTrue(text.contains("after"))
    }

    func testContainerViewContractStreamingUsesContractAnimationPlanMapper() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let mapper = SpyContractAnimationPlanMapper()
        view.contractAnimationPlanMapper = mapper

        _ = try view.appendContractStreamChunk("hello")

        XCTAssertGreaterThanOrEqual(mapper.callCount, 1)
    }

    func testContainerViewSetContractRenderModelWithAnimationPlanUsesMapper() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let mapper = SpyContractAnimationPlanMapper()
        view.contractAnimationPlanMapper = mapper

        try view.setContractMarkdown("legacy")

        let engine = MarkdownContractEngine()
        let model = try engine.render("# Title")
        let animationPlan = MarkdownContract.CompiledAnimationPlan(
            intents: [],
            timeline: .init(
                tracks: [],
                phases: [],
                constraints: []
            )
        )

        view.setContractRenderModel(model, animationPlan: animationPlan)

        XCTAssertGreaterThanOrEqual(mapper.callCount, 1)
    }
}

private final class SpyContractAnimationPlanMapper: ContractAnimationPlanMapping {
    private(set) var callCount: Int = 0

    func makePlan(
        contractPlan: MarkdownContract.CompiledAnimationPlan,
        oldFragments: [RenderFragment],
        newFragments: [RenderFragment],
        changes: [FragmentChange],
        defaultEffectKey: AnimationEffectKey
    ) -> AnimationPlan {
        callCount += 1
        return AnimationPlan(steps: [AnimationStep(
            id: "spy.step",
            effectKey: defaultEffectKey,
            changes: changes,
            oldFragments: oldFragments,
            newFragments: newFragments
        )])
    }
}
