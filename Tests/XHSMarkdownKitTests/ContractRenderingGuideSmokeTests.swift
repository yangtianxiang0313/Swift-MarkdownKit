import XCTest
import UIKit
@testable import XHSMarkdownKit

final class ContractRenderingGuideSmokeTests: XCTestCase {

    func testUIKitOverrideSnippetCompilesAndRenders() throws {
        let calloutKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "callout"))
        let mentionKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "mention"))

        let adapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )
        adapter.registerBlockMapper(forExtension: calloutKind.rawValue) { block, _, adapter in
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "callout",
                attributedText: NSAttributedString(string: "CALLOUT")
            )
            return [.mergeSegment(segment)]
        }
        adapter.registerInlineRenderer(forExtension: mentionKind.rawValue) { span, _, _, _ in
            NSAttributedString(string: "@\(span.text)")
        }

        let model = MarkdownContract.RenderModel(
            documentId: "doc.guide.override",
            blocks: [
                .init(id: "callout.1", kind: calloutKind),
                .init(
                    id: "paragraph.1",
                    kind: .paragraph,
                    inlines: [.init(id: "mention.1", kind: mentionKind, text: "alice")]
                )
            ]
        )

        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        XCTAssertFalse(scene.nodes.isEmpty)
        XCTAssertTrue(mergedText(from: scene).contains("CALLOUT"))
        XCTAssertTrue(mergedText(from: scene).contains("@alice"))
    }

    func testCustomStandaloneSnippetCompilesAndRenders() throws {
        let cardKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "card"))
        let adapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )

        adapter.registerBlockMapper(forExtension: cardKind.rawValue) { block, _, adapter in
            let node = adapter.makeCustomStandaloneNode(
                id: block.id,
                kind: "custom.card",
                reuseIdentifier: "custom.card",
                signature: "v1",
                revealUnitCount: 1,
                makeView: { GuideRevealCardView() },
                configure: { _, _ in }
            )
            return [.standalone(node)]
        }

        let model = MarkdownContract.RenderModel(
            documentId: "doc.guide.custom",
            blocks: [.init(id: "card.1", kind: cardKind)]
        )

        let scene = try adapter.render(model: model, theme: .default, maxWidth: 320)
        XCTAssertEqual(scene.nodes.count, 1)
        XCTAssertEqual(scene.nodes.first?.kind, "custom.card")
    }
}

private final class GuideRevealCardView: UIView, RevealLayoutAnimatableView {
    func applyRevealState(_ state: RevealState) {
        invalidateRevealLayout()
    }
}
