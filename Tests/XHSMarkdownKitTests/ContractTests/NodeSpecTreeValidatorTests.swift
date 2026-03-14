import XCTest
@testable import XHSMarkdownKit

final class NodeSpecTreeValidatorTests: XCTestCase {

    func testTreeValidatorAcceptsValidExtensionContainerStructure() throws {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let validator = MarkdownContract.TreeValidator(registry: specs)

        let doc = MarkdownContract.CanonicalDocument(
            documentId: "tree-valid",
            root: .init(
                id: "root",
                kind: .document,
                children: [
                    .init(
                        id: "tabs",
                        kind: ExtensionNodeTestSupport.tabsKind,
                        children: [
                            .init(
                                id: "p1",
                                kind: .paragraph,
                                children: [
                                    .init(id: "t1", kind: .text, attrs: ["text": .string("ok")], source: .init(sourceKind: .markdown))
                                ],
                                source: .init(sourceKind: .markdown)
                            )
                        ],
                        source: .init(sourceKind: .directive)
                    )
                ],
                source: .init(sourceKind: .markdown)
            )
        )

        XCTAssertNoThrow(try validator.validate(document: doc))
    }

    func testTreeValidatorRejectsInlineChildUnderBlockContainer() {
        let specs = ExtensionNodeTestSupport.makeNodeSpecRegistry()
        let validator = MarkdownContract.TreeValidator(registry: specs)

        let doc = MarkdownContract.CanonicalDocument(
            documentId: "tree-invalid",
            root: .init(
                id: "root",
                kind: .document,
                children: [
                    .init(
                        id: "tabs",
                        kind: ExtensionNodeTestSupport.tabsKind,
                        children: [
                            .init(id: "mention", kind: ExtensionNodeTestSupport.mentionKind, source: .init(sourceKind: .htmlTag))
                        ],
                        source: .init(sourceKind: .directive)
                    )
                ],
                source: .init(sourceKind: .markdown)
            )
        )

        XCTAssertThrowsError(try validator.validate(document: doc)) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                return XCTFail("Expected ModelError")
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.schemaInvalid.rawValue)
            XCTAssertEqual(modelError.path, "root.children[0].children[0]")
        }
    }

    func testRenderModelDiffUsesUpdateForSameNodeIDAndInsertRemoveForStructureChange() {
        let differ = MarkdownContract.DefaultRenderModelDiffer()

        let old = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [
                .init(id: "tabs", kind: .custom, metadata: ["state": .string("old")])
            ]
        )
        let updated = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [
                .init(id: "tabs", kind: .custom, metadata: ["state": .string("new")])
            ]
        )

        let updateDiff = differ.diff(old: old, new: updated)
        XCTAssertEqual(updateDiff.flattenedChanges.count, 1)
        XCTAssertEqual(updateDiff.flattenedChanges.first?.type, .update)

        let structureChanged = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [
                .init(id: "tabs-new", kind: .custom, metadata: ["state": .string("new")])
            ]
        )
        let structureDiff = differ.diff(old: old, new: structureChanged)

        XCTAssertTrue(structureDiff.flattenedChanges.contains(where: { $0.type == .remove && $0.nodeId == "tabs" }))
        XCTAssertTrue(structureDiff.flattenedChanges.contains(where: { $0.type == .insert && $0.nodeId == "tabs-new" }))
    }
}
