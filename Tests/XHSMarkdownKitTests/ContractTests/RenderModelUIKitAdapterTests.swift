import XCTest
import UIKit
@testable import XHSMarkdownKit

final class RenderModelUIKitAdapterTests: XCTestCase {

    func testAdapterRendersHeadingAndParagraphFragments() throws {
        let engine = MarkdownContractEngine()
        let model = try engine.render("# Title\n\nBody")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        let fragments = adapter.render(
            model: model,
            theme: .default,
            maxWidth: 320
        )

        XCTAssertTrue(fragments.contains(where: { $0.nodeType.rawValue == FragmentNodeType.heading1.rawValue }))
        XCTAssertTrue(fragments.contains(where: { $0.nodeType == .paragraph }))
        XCTAssertTrue(mergedText(from: fragments).contains("Title"))
        XCTAssertTrue(mergedText(from: fragments).contains("Body"))
    }

    func testAdapterAllowsOverridingStandardBlockRenderer() throws {
        let engine = MarkdownContractEngine()
        let model = try engine.render("# Title")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerBlockRenderer(for: .heading) { block, context, _ in
            let attributed = NSAttributedString(string: "OVERRIDE")
            let fragmentContext = context.makeFragmentContext()

            return [ContractTextFragment(
                fragmentId: block.id,
                nodeType: .heading1,
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

        let fragments = adapter.render(
            model: model,
            theme: .default,
            maxWidth: 320
        )

        XCTAssertEqual(mergedText(from: fragments).trimmingCharacters(in: .whitespacesAndNewlines), "OVERRIDE")
    }

    func testAdapterAllowsOverridingInlineCustomElementRenderer() throws {
        let engine = MarkdownContractEngine()
        let model = try engine.render("before <badge text=\"new\" /> after")

        let adapter = MarkdownContract.RenderModelUIKitAdapter()
        adapter.registerInlineRenderer(forCustomElement: "badge") { _, _, _, _ in
            NSAttributedString(string: "[BADGE]")
        }

        let fragments = adapter.render(
            model: model,
            theme: .default,
            maxWidth: 320
        )
        let text = mergedText(from: fragments)

        XCTAssertTrue(text.contains("before"))
        XCTAssertTrue(text.contains("[BADGE]"))
        XCTAssertTrue(text.contains("after"))
        XCTAssertFalse(text.contains("<badge"))
    }

    func testAdapterUsesContractSpecificFragmentsByDefault() throws {
        let engine = MarkdownContractEngine()
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
        let fragments = adapter.render(model: model, theme: .default, maxWidth: 320)

        XCTAssertTrue(fragments.contains(where: { $0 is ContractTextFragment }))
        XCTAssertTrue(fragments.contains(where: {
            guard let fragment = $0 as? ContractViewFragment else { return false }
            return fragment.reuseIdentifier == .contractCodeBlockView
        }))
        XCTAssertTrue(fragments.contains(where: {
            guard let fragment = $0 as? ContractViewFragment else { return false }
            return fragment.reuseIdentifier == .contractThematicBreakView
        }))
        XCTAssertTrue(fragments.contains(where: { $0 is ContractBlockQuoteContainerFragment }))
    }
}
