import XCTest
@testable import XHSMarkdownKit

final class PipelineRenderTests: XCTestCase {

    func testRenderHeadingAndParagraph() {
        let fragments = render("# Title\n\nBody text")
        let text = mergedText(from: fragments)

        XCTAssertFalse(fragments.isEmpty)
        XCTAssertTrue(text.contains("Title"))
        XCTAssertTrue(text.contains("Body text"))
    }

    func testRenderTableGeneratesTableFragment() {
        let markdown = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """

        let fragments = render(markdown)
        let tableFragments = fragments.filter { $0.nodeType == .table }

        XCTAssertEqual(tableFragments.count, 1)
        XCTAssertTrue((tableFragments.first as? ViewFragment)?.reuseIdentifier == .markdownTableView)
    }

    func testCustomSpacingResolverAppliedToAdjacentBlocks() {
        let fragments = render(
            "Paragraph 1\n\n```swift\nprint(1)\n```",
            spacingResolver: FixedSpacingResolver(42)
        )

        XCTAssertGreaterThanOrEqual(fragments.count, 2)
        XCTAssertEqual(fragments[0].spacingAfter, 42)
    }

    func testPlainTextParagraphsAreMerged() {
        let fragments = render("Hello\n\nWorld")

        let paragraphFragments = fragments.filter { $0.nodeType == .paragraph }
        XCTAssertEqual(paragraphFragments.count, 1)

        let text = mergedText(from: fragments)
        XCTAssertTrue(text.contains("Hello"))
        XCTAssertTrue(text.contains("World"))
    }

    func testHeadingAndParagraphAreMergedWithSpacing() {
        let fragments = render("# Title\n\nBody")

        let textFragments = fragments.compactMap { $0 as? AttributedStringProviding }
        XCTAssertEqual(textFragments.count, 1)

        guard let attributed = textFragments.first?.attributedString else {
            XCTFail("Expected merged attributed string")
            return
        }

        let ns = attributed.string as NSString
        let newlineLocation = ns.range(of: "\n").location
        XCTAssertNotEqual(newlineLocation, NSNotFound)

        let attrs = attributed.attributes(at: newlineLocation, effectiveRange: nil)
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        XCTAssertGreaterThan(paragraphStyle?.paragraphSpacing ?? 0, 0)
    }

    func testMergedTextUsesTrailingNodeTypeForExternalSpacing() {
        let fragments = render(
            "# Title\n\nBody\n\n```swift\nprint(1)\n```",
            spacingResolver: FixedSpacingResolver(42)
        )

        XCTAssertGreaterThanOrEqual(fragments.count, 2)
        XCTAssertEqual(fragments[0].spacingAfter, 42)
    }
}
