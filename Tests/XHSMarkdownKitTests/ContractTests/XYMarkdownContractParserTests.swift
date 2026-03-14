import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class XYMarkdownContractParserTests: XCTestCase {

    func testParsesRegisteredDirectiveAsExtensionBlockLeafNode() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = "@Callout"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-callout", parseBlockDirectives: true))
        let nodes = flatten(document.root)

        let callout = nodes.first {
            $0.kind == ExtensionNodeTestSupport.calloutKind && $0.source.sourceKind == .directive
        }
        XCTAssertNotNil(callout)
        XCTAssertEqual(callout?.attrs["name"], .string("Callout"))
    }

    func testParsesRegisteredDirectiveAsExtensionBlockContainerNode() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = """
        @Tabs {
        One
        }
        """

        let document = try parser.parse(markdown, options: .init(documentId: "doc-tabs", parseBlockDirectives: true))
        let nodes = flatten(document.root)
        let tabs = nodes.first { $0.kind == ExtensionNodeTestSupport.tabsKind }

        XCTAssertNotNil(tabs)
        XCTAssertFalse(tabs?.children.isEmpty ?? true)
    }

    func testParsesRegisteredHTMLAsExtensionInlineLeafNode() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = "before <mention userId=\"alice\" /> after"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-mention"))
        let nodes = flatten(document.root)

        let mention = nodes.first {
            $0.kind == ExtensionNodeTestSupport.mentionKind && $0.source.sourceKind == .htmlTag
        }

        XCTAssertNotNil(mention)
        if case let .object(attributes)? = mention?.attrs["attributes"] {
            XCTAssertEqual(attributes["userId"], .string("alice"))
        } else {
            XCTFail("Expected mention attributes")
        }
    }

    func testParsesRegisteredHTMLAsExtensionInlineContainerNode() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = "before <spoiler /> after"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-spoiler"))
        let nodes = flatten(document.root)

        let spoiler = nodes.first {
            $0.kind == ExtensionNodeTestSupport.spoilerKind && $0.source.sourceKind == .htmlTag
        }
        XCTAssertNotNil(spoiler)
    }

    func testUnregisteredExtensionNodeFailsStrictly() {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: .core())

        XCTAssertThrowsError(try parser.parse("<mention userId=\"bob\" />", options: .init(documentId: "doc-unregistered"))) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                return XCTFail("Expected ModelError")
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.unknownNodeKind.rawValue)
            XCTAssertTrue(modelError.path?.contains("kind") ?? false)
        }
    }

    func testDisablingDirectiveParsingKeepsSourceKindMarkdown() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = "@Tabs"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-3", parseBlockDirectives: false))
        let nodes = flatten(document.root)

        XCTAssertFalse(nodes.contains(where: { $0.source.sourceKind == .directive }))
    }

    func testTableNodeContainsStructuredHeadersRowsAndAlignments() throws {
        let parser = XYMarkdownContractParser()
        let markdown = """
        | name | age |
        | :--- | ---:|
        | tom  | 10  |
        | bob  | 12  |
        """

        let document = try parser.parse(markdown, options: .init(documentId: "doc-table"))
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

    func testTableNodeRetainsNilAlignmentSlots() throws {
        let parser = XYMarkdownContractParser()
        let markdown = """
        | a | b | c |
        | :-- | --- | --: |
        | 1 | 2 | 3 |
        """

        let document = try parser.parse(markdown, options: .init(documentId: "doc-table-alignment"))
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
