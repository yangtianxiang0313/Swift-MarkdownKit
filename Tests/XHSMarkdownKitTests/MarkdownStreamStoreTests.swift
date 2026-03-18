import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

@MainActor
final class MarkdownStreamStoreTests: XCTestCase {

    func testCreateAppendFinishAndIdempotency() throws {
        let store = MarkdownStreamStore(engine: ExtensionNodeTestSupport.makeEngine())
        let ref = store.createStream(documentID: "doc.stream.1")

        let initial = try store.snapshot(ref: ref)
        XCTAssertEqual(initial.revision, 0)
        XCTAssertFalse(initial.isFinal)
        XCTAssertEqual(initial.textLength, 0)

        let appendTime = MarkdownStreamTimePoint(seconds: 100)
        let firstEvent = try store.append(ref: ref, chunk: "hello", at: appendTime)
        let first = firstEvent.snapshot
        XCTAssertEqual(first.revision, 1)
        XCTAssertFalse(first.isFinal)
        XCTAssertEqual(first.textLength, 5)
        XCTAssertEqual(firstEvent.latestUpdate?.sequence, 1)
        XCTAssertEqual(first.animatedRanges.count, 1)
        XCTAssertEqual(first.animatedRanges[0].start, 0)
        XCTAssertEqual(first.animatedRanges[0].end, 5)
        XCTAssertEqual(first.animatedRanges[0].progress, 0)

        let inFlight = try store.snapshot(ref: ref, at: .init(seconds: 100.375))
        XCTAssertEqual(inFlight.animatedRanges.count, 1)
        XCTAssertGreaterThan(inFlight.animatedRanges[0].progress, 0.45)
        XCTAssertLessThan(inFlight.animatedRanges[0].progress, 0.55)

        let completed = try store.snapshot(ref: ref, at: .init(seconds: 101))
        XCTAssertEqual(completed.animatedRanges.count, 0)

        let finalEvent = try store.finish(ref: ref, at: .init(seconds: 101))
        let final = finalEvent.snapshot
        XCTAssertTrue(final.isFinal)
        XCTAssertEqual(final.revision, 2)
        XCTAssertEqual(finalEvent.latestUpdate?.sequence, 2)
        XCTAssertEqual(finalEvent.latestUpdate?.isFinal, true)

        let finishedAgain = try store.finish(ref: ref, at: .init(seconds: 102)).snapshot
        XCTAssertTrue(finishedAgain.isFinal)
        XCTAssertEqual(finishedAgain.revision, 2)

        XCTAssertThrowsError(try store.append(ref: ref, chunk: "!")) { error in
            XCTAssertEqual(error as? MarkdownStreamStoreError, .streamAlreadyFinished)
        }
    }

    func testObserveReceivesInitialAndIncrementalSnapshots() throws {
        let store = MarkdownStreamStore(engine: ExtensionNodeTestSupport.makeEngine())
        let ref = store.createStream(documentID: "doc.stream.observe")

        var revisions: [Int] = []
        var hasLatestUpdateFlags: [Bool] = []
        let observation = try store.observe(ref: ref) { event in
            revisions.append(event.snapshot.revision)
            hasLatestUpdateFlags.append(event.latestUpdate != nil)
        }

        _ = try store.append(ref: ref, chunk: "A")
        _ = try store.append(ref: ref, chunk: "B")
        _ = try store.finish(ref: ref)

        XCTAssertEqual(revisions, [0, 1, 2, 3])
        XCTAssertEqual(hasLatestUpdateFlags, [false, true, true, true])

        observation.cancel()
        _ = try? store.snapshot(ref: ref)
    }

    func testTimelineProgressesWithoutActiveViewBinding() throws {
        let store = MarkdownStreamStore(engine: ExtensionNodeTestSupport.makeEngine())
        let ref = store.createStream(documentID: "doc.stream.timeline")

        _ = try store.append(
            ref: ref,
            chunk: "abcdef",
            at: MarkdownStreamTimePoint(seconds: 10)
        )

        let hiddenAtStart = try store.snapshot(ref: ref, at: .init(seconds: 10))
        XCTAssertEqual(hiddenAtStart.animatedRanges.count, 1)
        XCTAssertEqual(hiddenAtStart.animatedRanges[0].progress, 0)

        let hiddenLater = try store.snapshot(ref: ref, at: .init(seconds: 10.6))
        XCTAssertEqual(hiddenLater.animatedRanges.count, 1)
        XCTAssertGreaterThan(hiddenLater.animatedRanges[0].progress, 0.75)
        XCTAssertLessThan(hiddenLater.animatedRanges[0].progress, 0.85)

        let hiddenDone = try store.snapshot(ref: ref, at: .init(seconds: 11))
        XCTAssertEqual(hiddenDone.animatedRanges.count, 0)
    }

    func testObserveInitialEventContainsLatestUpdateAfterStreaming() throws {
        let store = MarkdownStreamStore(engine: ExtensionNodeTestSupport.makeEngine())
        let ref = store.createStream(documentID: "doc.stream.rebind")
        _ = try store.append(ref: ref, chunk: "hello")

        var firstEvent: MarkdownStreamEvent?
        let observation = try store.observe(ref: ref) { event in
            if firstEvent == nil {
                firstEvent = event
            }
        }

        XCTAssertEqual(firstEvent?.snapshot.revision, 1)
        XCTAssertEqual(firstEvent?.latestUpdate?.sequence, 1)
        observation.cancel()
    }

    func testActiveRangesAreCompactedOverLongStreams() throws {
        let store = MarkdownStreamStore(
            engine: ExtensionNodeTestSupport.makeEngine(),
            defaultRangeDurationSeconds: 0.2
        )
        let ref = store.createStream(documentID: "doc.stream.compact")

        for index in 0..<50 {
            _ = try store.append(
                ref: ref,
                chunk: "a",
                at: .init(seconds: 100 + (Double(index) * 0.25))
            )
        }

        let snapshot = try store.snapshot(ref: ref, at: .init(seconds: 200))
        XCTAssertEqual(snapshot.animatedRanges.count, 0)
    }
}
