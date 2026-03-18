import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class MarkdownStreamStoreTests: XCTestCase {

    func testCreateAppendFinishAndErrorBehavior() throws {
        let store = MarkdownRenderStore(engine: ExtensionNodeTestSupport.makeEngine())
        let ref = try store.createStream(documentID: "doc.render.1")

        let initial = try XCTUnwrap(store.streamRecord(ref: ref))
        XCTAssertEqual(initial.revision, 0)
        XCTAssertEqual(initial.sequence, 0)
        XCTAssertFalse(initial.isFinal)
        XCTAssertEqual(initial.currentText, "")
        XCTAssertNil(initial.latestUpdate)

        let first = try store.appendChunk(ref: ref, chunk: "hello")
        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(first.sequence, 1)
        XCTAssertFalse(first.isFinal)
        XCTAssertEqual(first.currentText, "hello")

        let second = try store.appendChunk(ref: ref, chunk: " world")
        XCTAssertEqual(second.revision, 2)
        XCTAssertEqual(second.sequence, 2)
        XCTAssertEqual(second.currentText, "hello world")

        let finished = try store.finishStream(ref: ref)
        XCTAssertTrue(finished.isFinal)
        XCTAssertEqual(finished.sequence, 3)
        XCTAssertEqual(finished.currentText, "hello world")

        XCTAssertThrowsError(try store.appendChunk(ref: ref, chunk: "!")) { error in
            XCTAssertEqual(error as? MarkdownRenderStoreError, .streamAlreadyFinished)
        }
    }

    func testObserveReceivesRevisionDrivenEvents() throws {
        let store = MarkdownRenderStore(engine: ExtensionNodeTestSupport.makeEngine())

        var kinds: [MarkdownRenderStoreEventKind] = []
        let observation = store.observe { event in
            kinds.append(event.kind)
        }

        let ref = try store.createStream(documentID: "doc.observe")
        _ = try store.appendChunk(ref: ref, chunk: "A")
        _ = try store.finishStream(ref: ref)
        store.removeStream(ref: ref)

        observation.cancel()

        XCTAssertGreaterThanOrEqual(kinds.count, 5)
        XCTAssertTrue(kinds.contains(.streamCreated(ref: ref)))
        XCTAssertTrue(kinds.contains(.streamUpdated(ref: ref)))
        XCTAssertTrue(kinds.contains(.streamFinished(ref: ref)))
        XCTAssertTrue(kinds.contains(.streamRemoved(ref: ref)))
    }

    func testAnimationStateBackedBySingleStore() {
        let store = MarkdownRenderStore()
        let keyA = AnimationEntityKey(documentId: "doc.anim", entityId: "a")
        let keyB = AnimationEntityKey(documentId: "doc.anim", entityId: "b")

        store.setAnimationState(
            AnimationEntityProgressState(
                displayedUnits: 3,
                stableUnits: 2,
                targetUnits: 5,
                lastVersion: 1
            ),
            for: keyA
        )
        store.setAnimationState(
            AnimationEntityProgressState(
                displayedUnits: 1,
                stableUnits: 1,
                targetUnits: 4,
                lastVersion: 1
            ),
            for: keyB
        )

        var docStates = store.animationStates(documentID: "doc.anim")
        XCTAssertEqual(docStates.count, 2)

        store.prepareAnimationState(documentID: "doc.anim", revealUnitsByEntity: ["a": 2])
        docStates = store.animationStates(documentID: "doc.anim")

        XCTAssertEqual(docStates.count, 1)
        let clamped = docStates[keyA]
        XCTAssertEqual(clamped?.displayedUnits, 2)
        XCTAssertEqual(clamped?.stableUnits, 2)
        XCTAssertEqual(clamped?.targetUnits, 2)

        store.removeAnimationStates(documentID: "doc.anim")
        XCTAssertTrue(store.animationStates(documentID: "doc.anim").isEmpty)
    }

    func testCreateStreamWithoutEngineThrows() {
        let store = MarkdownRenderStore()
        XCTAssertThrowsError(try store.createStream(documentID: "doc.no.engine")) { error in
            XCTAssertEqual(error as? MarkdownRenderStoreError, .streamingEngineNotConfigured)
        }
    }
}
