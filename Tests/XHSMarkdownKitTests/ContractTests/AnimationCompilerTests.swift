import XCTest
@testable import XHSMarkdownKit

final class AnimationCompilerTests: XCTestCase {

    func testCompilesIntentAndTimelineFromDiff() {
        let old = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [MarkdownContract.RenderBlock(id: "a", kind: .paragraph)]
        )
        let new = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [
                MarkdownContract.RenderBlock(id: "a", kind: .paragraph),
                MarkdownContract.RenderBlock(id: "b", kind: .paragraph)
            ]
        )

        let differ = MarkdownContract.DefaultRenderModelDiffer()
        let diff = differ.diff(old: old, new: new)
        let compiler = MarkdownContract.DefaultRenderModelAnimationCompiler()

        let plan = compiler.compile(old: old, new: new, diff: diff)

        XCTAssertEqual(plan.intents.count, diff.flattenedChanges.count)
        XCTAssertTrue(plan.intents.contains(where: { $0.entityId == "b" && $0.type == "insert" }))
        XCTAssertEqual(plan.timeline.schemaVersion, MarkdownContract.schemaVersion)
        XCTAssertFalse(plan.timeline.tracks.isEmpty)
    }

    func testCompilerIsDeterministic() {
        let old = MarkdownContract.RenderModel(documentId: "doc", blocks: [])
        let new = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [MarkdownContract.RenderBlock(id: "a", kind: .paragraph)]
        )

        let differ = MarkdownContract.DefaultRenderModelDiffer()
        let diff = differ.diff(old: old, new: new)
        let compiler = MarkdownContract.DefaultRenderModelAnimationCompiler()

        let first = compiler.compile(old: old, new: new, diff: diff)
        let second = compiler.compile(old: old, new: new, diff: diff)

        XCTAssertEqual(first, second)
    }

    func testCompilerAddsPhaseEffectKeys() {
        let old = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [MarkdownContract.RenderBlock(id: "a", kind: .paragraph)]
        )
        let new = MarkdownContract.RenderModel(
            documentId: "doc",
            blocks: [
                MarkdownContract.RenderBlock(id: "a", kind: .heading),
                MarkdownContract.RenderBlock(id: "b", kind: .paragraph)
            ]
        )

        let differ = MarkdownContract.DefaultRenderModelDiffer()
        let diff = differ.diff(old: old, new: new)
        let compiler = MarkdownContract.DefaultRenderModelAnimationCompiler()

        let plan = compiler.compile(old: old, new: new, diff: diff)
        let byID = Dictionary(uniqueKeysWithValues: plan.timeline.phases.map { ($0.id, $0) })

        if let structure = byID["phase.structure"] {
            XCTAssertEqual(structure.metadata["effectKey"], .string("segmentFade"))
        }
        if let content = byID["phase.content"] {
            XCTAssertEqual(content.metadata["effectKey"], .string("typing"))
        }
    }
}
