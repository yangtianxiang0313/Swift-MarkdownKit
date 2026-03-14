import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class XYMarkdownContractParserTests: XCTestCase {

    func testParsesDirectiveAsCustomElementNode() {
        let parser = XYMarkdownContractParser()
        let markdown = """
        @Card(title: \"hero\") {
        Hello
        }
        """

        let document = parser.parse(markdown, options: .init(documentId: "doc-1", parseBlockDirectives: true))
        let nodes = flatten(document.root)

        let directiveNodes = nodes.filter {
            $0.kind == .customElement && $0.source.sourceKind == .directive
        }

        XCTAssertFalse(directiveNodes.isEmpty)
        XCTAssertEqual(directiveNodes.first?.attrs["name"], .string("Card"))
    }

    func testParsesHTMLTagAsCustomElementNode() {
        let parser = XYMarkdownContractParser()
        let markdown = "before <badge text=\"new\" /> after"

        let document = parser.parse(markdown, options: .init(documentId: "doc-2"))
        let nodes = flatten(document.root)

        let htmlNodes = nodes.filter {
            $0.kind == .customElement && $0.source.sourceKind == .htmlTag
        }

        XCTAssertFalse(htmlNodes.isEmpty)
        XCTAssertEqual(htmlNodes.first?.attrs["name"], .string("badge"))
    }

    func testDisablingDirectiveParsingKeepsSourceKindMarkdown() {
        let parser = XYMarkdownContractParser()
        let markdown = "@TOC"

        let document = parser.parse(markdown, options: .init(documentId: "doc-3", parseBlockDirectives: false))
        let nodes = flatten(document.root)

        XCTAssertFalse(nodes.contains(where: { $0.source.sourceKind == .directive }))
    }

    func testTableNodeContainsStructuredHeadersRowsAndAlignments() {
        let parser = XYMarkdownContractParser()
        let markdown = """
        | name | age |
        | :--- | ---:|
        | tom  | 10  |
        | bob  | 12  |
        """

        let document = parser.parse(markdown, options: .init(documentId: "doc-table"))
        let nodes = flatten(document.root)

        guard let table = nodes.first(where: { $0.kind == .table }) else {
            XCTFail("table node not found")
            return
        }

        XCTAssertEqual(
            table.attrs["headers"],
            .array([.string("name"), .string("age")])
        )
        XCTAssertEqual(
            table.attrs["rows"],
            .array([
                .array([.string("tom"), .string("10")]),
                .array([.string("bob"), .string("12")])
            ])
        )
        XCTAssertEqual(
            table.attrs["alignments"],
            .array([.string("left"), .string("right")])
        )
    }

    func testTableNodeRetainsNilAlignmentSlots() {
        let parser = XYMarkdownContractParser()
        let markdown = """
        | a | b | c |
        | :-- | --- | --: |
        | 1 | 2 | 3 |
        """

        let document = parser.parse(markdown, options: .init(documentId: "doc-table-alignment"))
        let nodes = flatten(document.root)

        guard let table = nodes.first(where: { $0.kind == .table }) else {
            XCTFail("table node not found")
            return
        }

        XCTAssertEqual(
            table.attrs["alignments"],
            .array([.string("left"), .null, .string("right")])
        )
    }

    private func flatten(_ root: MarkdownContract.CanonicalNode) -> [MarkdownContract.CanonicalNode] {
        var result: [MarkdownContract.CanonicalNode] = [root]
        for child in root.children {
            result.append(contentsOf: flatten(child))
        }
        return result
    }
}
