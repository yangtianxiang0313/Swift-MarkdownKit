import XCTest
@testable import XHSMarkdownKit

final class RenderModelDiffTests: XCTestCase {

    func testDetectsInsertChange() {
        let differ = MarkdownContract.DefaultRenderModelDiffer()
        let old = makeModel(blocks: [])
        let new = makeModel(blocks: [block(id: "a", text: "A")])

        let diff = differ.diff(old: old, new: new)

        XCTAssertEqual(diff.changes.count, 1)
        XCTAssertEqual(diff.changes.first?.type, .insert)
        XCTAssertEqual(diff.changes.first?.toPath, [0])
    }

    func testDetectsMoveAndUpdateChanges() {
        let differ = MarkdownContract.DefaultRenderModelDiffer()
        let old = makeModel(blocks: [
            block(id: "a", text: "A"),
            block(id: "b", text: "B")
        ])
        let new = makeModel(blocks: [
            block(id: "b", text: "B2"),
            block(id: "a", text: "A")
        ])

        let diff = differ.diff(old: old, new: new)

        XCTAssertTrue(diff.changes.contains(where: { $0.type == .move && $0.nodeId == "b" }))
        XCTAssertTrue(diff.changes.contains(where: { $0.type == .update && $0.nodeId == "b" }))
    }

    func testDetectsNestedChildChanges() {
        let differ = MarkdownContract.DefaultRenderModelDiffer()

        let oldChild = block(id: "child", text: "old")
        let newChild = block(id: "child", text: "new")

        let oldParent = MarkdownContract.RenderBlock(id: "p", kind: .custom, children: [oldChild])
        let newParent = MarkdownContract.RenderBlock(id: "p", kind: .custom, children: [newChild])

        let old = makeModel(blocks: [oldParent])
        let new = makeModel(blocks: [newParent])

        let diff = differ.diff(old: old, new: new)

        guard let parentUpdate = diff.changes.first(where: { $0.nodeId == "p" && $0.type == .update }) else {
            XCTFail("Expected parent update")
            return
        }

        XCTAssertTrue(parentUpdate.childChanges.contains(where: { $0.nodeId == "child" && $0.type == .update }))
    }

    private func makeModel(blocks: [MarkdownContract.RenderBlock]) -> MarkdownContract.RenderModel {
        MarkdownContract.RenderModel(documentId: "doc", blocks: blocks)
    }

    private func block(id: String, text: String) -> MarkdownContract.RenderBlock {
        MarkdownContract.RenderBlock(
            id: id,
            kind: .paragraph,
            inlines: [MarkdownContract.InlineSpan(id: "\(id).i", kind: .text, text: text)]
        )
    }
}
