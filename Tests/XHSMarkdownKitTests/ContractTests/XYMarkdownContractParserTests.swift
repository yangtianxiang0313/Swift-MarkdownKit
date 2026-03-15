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

    func testParsesPairedHTMLTagAsInlineContainerWithChildren() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = "prefix <Cite id=\"ref-1\">abcdfe</Cite> suffix"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-cite-paired"))
        let nodes = flatten(document.root)
        guard let cite = nodes.first(where: { $0.kind == ExtensionNodeTestSupport.citeKind }) else {
            XCTFail("Expected cite extension node")
            return
        }

        XCTAssertEqual(cite.source.sourceKind, .htmlTag)
        XCTAssertFalse(cite.children.isEmpty)
        XCTAssertTrue(cite.children.contains(where: { node in
            node.kind == .text && node.attrs["text"] == .string("abcdfe")
        }))
    }

    func testParsesPairedHTMLTagAsBlockContainerWithChildren() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = """
        <Think id="think-1">
        - step 1
        - step 2
        </Think>
        """

        let document = try parser.parse(markdown, options: .init(documentId: "doc-think-paired"))
        let nodes = flatten(document.root)
        guard let think = nodes.first(where: { $0.kind == ExtensionNodeTestSupport.thinkKind }) else {
            XCTFail("Expected think extension node")
            return
        }

        XCTAssertEqual(think.source.sourceKind, .htmlTag)
        XCTAssertFalse(think.children.isEmpty)
        XCTAssertTrue(flatten(think).contains(where: { node in
            node.kind == .text && node.attrs["text"] == .string("step 1")
        }))
    }

    func testSelfClosingOnlyTagDoesNotConsumePairedBody() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = "start <mention userId=\"bob\">hello</mention> end"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-self-closing-only"))
        let nodes = flatten(document.root)

        let mentionNodes = nodes.filter { $0.kind == ExtensionNodeTestSupport.mentionKind }
        XCTAssertEqual(mentionNodes.count, 1)
        XCTAssertTrue(nodes.contains(where: { node in
            node.kind == .text && node.attrs["text"] == .string("hello")
        }))
    }

    func testClosingHTMLTagsAreIgnoredForExtensionResolution() throws {
        let spotlightKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "spotlight"))
        let specs = MarkdownContract.NodeSpecRegistry.core()
        specs.register(.init(
            kind: spotlightKind,
            role: .blockContainer,
            childPolicy: .blockOnly(minChildren: 0),
            parseAliases: [.init(sourceKind: .htmlTag, name: "spotlight")]
        ))

        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let markdown = """
        <spotlight type="info">
        inner
        </spotlight>
        """

        let document = try parser.parse(markdown, options: .init(documentId: "doc-closing-tag"))
        let nodes = flatten(document.root)

        XCTAssertTrue(nodes.contains(where: { $0.kind == spotlightKind }))
        XCTAssertFalse(nodes.contains(where: { node in
            if case let .bool(isClosing)? = node.attrs["isClosing"] {
                return isClosing
            }
            return false
        }))
        XCTAssertFalse(nodes.contains(where: { node in
            if case let .ext(extensionKind) = node.kind {
                return extensionKind.rawValue.hasPrefix("ext.unregistered.")
            }
            return false
        }))
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

    func testParsesStrikethroughAsCoreNodeKind() throws {
        let parser = XYMarkdownContractParser()
        let markdown = "before ~~gone~~ after"

        let document = try parser.parse(markdown, options: .init(documentId: "doc-strikethrough"))
        let nodes = flatten(document.root)

        let strike = nodes.first { $0.kind == .strikethrough }
        XCTAssertNotNil(strike)
    }

    func testListItemWithLeadingInlineExtensionParsesSuccessfully() throws {
        let parser = XYMarkdownContractParser(nodeSpecRegistry: ExtensionNodeTestSupport.makeNodeSpecRegistry())
        let markdown = """
        - <mention userId="alice" />
        - <Cite id="ref-list-1">ref-list-1</Cite>
        """

        let document = try parser.parse(markdown, options: .init(documentId: "doc-list-leading-inline-ext"))
        let nodes = flatten(document.root)

        XCTAssertTrue(nodes.contains(where: { $0.kind == .list }))
        XCTAssertTrue(nodes.contains(where: { $0.kind == .listItem }))
        XCTAssertTrue(nodes.contains(where: { $0.kind == ExtensionNodeTestSupport.mentionKind }))
        XCTAssertTrue(nodes.contains(where: { $0.kind == ExtensionNodeTestSupport.citeKind }))
    }

    private func flatten(_ root: MarkdownContract.CanonicalNode) -> [MarkdownContract.CanonicalNode] {
        var result: [MarkdownContract.CanonicalNode] = [root]
        for child in root.children {
            result.append(contentsOf: flatten(child))
        }
        return result
    }
}
