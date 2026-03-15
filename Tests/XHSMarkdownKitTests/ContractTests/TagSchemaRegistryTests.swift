import XCTest
@testable import XHSMarkdownKit

final class TagSchemaRegistryTests: XCTestCase {

    func testTagSchemaRegistryInstallsNodeSpecAliasAndPairingMode() {
        let citeKind: MarkdownContract.NodeKind = .ext(.init(namespace: "schema", name: "cite"))
        let schemaRegistry = MarkdownContract.TagSchemaRegistry(
            schemas: [
                .init(
                    tagName: "Cite",
                    nodeKind: citeKind,
                    role: .inlineContainer,
                    childPolicy: .inlineOnly(minChildren: 0),
                    pairingMode: .paired
                )
            ]
        )
        let nodeSpecs = MarkdownContract.NodeSpecRegistry.core()
        schemaRegistry.install(into: nodeSpecs)

        XCTAssertEqual(nodeSpecs.resolveKind(sourceKind: .htmlTag, name: "cite"), citeKind)
        XCTAssertEqual(nodeSpecs.tagPairingMode(forHTMLTagName: "cite"), .paired)
    }

    func testTagSchemaChildPolicyParticipatesInTreeValidation() {
        let citeKind: MarkdownContract.NodeKind = .ext(.init(namespace: "schema", name: "cite"))
        let schemaRegistry = MarkdownContract.TagSchemaRegistry(
            schemas: [
                .init(
                    tagName: "cite",
                    nodeKind: citeKind,
                    role: .inlineContainer,
                    childPolicy: .inlineOnly(minChildren: 0),
                    pairingMode: .paired
                )
            ]
        )

        let nodeSpecs = MarkdownContract.NodeSpecRegistry.core()
        schemaRegistry.install(into: nodeSpecs)
        let validator = MarkdownContract.TreeValidator(registry: nodeSpecs)

        let valid = MarkdownContract.CanonicalDocument(
            documentId: "schema-valid",
            root: .init(
                id: "root",
                kind: .document,
                children: [
                    .init(
                        id: "p",
                        kind: .paragraph,
                        children: [
                            .init(
                                id: "cite",
                                kind: citeKind,
                                children: [
                                    .init(
                                        id: "text",
                                        kind: .text,
                                        attrs: ["text": .string("ok")],
                                        source: .init(sourceKind: .markdown)
                                    )
                                ],
                                source: .init(sourceKind: .htmlTag)
                            )
                        ],
                        source: .init(sourceKind: .markdown)
                    )
                ],
                source: .init(sourceKind: .markdown)
            )
        )
        XCTAssertNoThrow(try validator.validate(document: valid))

        let invalid = MarkdownContract.CanonicalDocument(
            documentId: "schema-invalid",
            root: .init(
                id: "root",
                kind: .document,
                children: [
                    .init(
                        id: "p",
                        kind: .paragraph,
                        children: [
                            .init(
                                id: "cite",
                                kind: citeKind,
                                children: [
                                    .init(
                                        id: "paragraph-child",
                                        kind: .paragraph,
                                        source: .init(sourceKind: .markdown)
                                    )
                                ],
                                source: .init(sourceKind: .htmlTag)
                            )
                        ],
                        source: .init(sourceKind: .markdown)
                    )
                ],
                source: .init(sourceKind: .markdown)
            )
        )

        XCTAssertThrowsError(try validator.validate(document: invalid)) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                return XCTFail("Expected ModelError")
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.schemaInvalid.rawValue)
        }
    }
}
