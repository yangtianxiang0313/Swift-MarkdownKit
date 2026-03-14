import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class StreamingMarkdownSessionTests: XCTestCase {

    func testAppendChunkProducesIncrementalUpdates() throws {
        let session = MarkdownContract.StreamingMarkdownSession(
            engine: MarkdownnAdapter.makeEngine(),
            parseOptions: .init(documentId: "stream-doc")
        )

        let first = try session.appendChunk("Hello")
        XCTAssertEqual(first.sequence, 1)
        XCTAssertFalse(first.isFinal)
        XCTAssertFalse(first.diff.isEmpty)

        let second = try session.appendChunk(" world")
        XCTAssertEqual(second.sequence, 2)
        XCTAssertEqual(second.currentText, "Hello world")
        XCTAssertTrue(second.model.blocks.contains(where: { $0.kind == .paragraph }))
    }

    func testFinishMarksFinalUpdate() throws {
        let session = MarkdownContract.StreamingMarkdownSession(
            engine: MarkdownnAdapter.makeEngine(),
            parseOptions: .init(documentId: "stream-doc")
        )

        _ = try session.appendChunk("# Title")
        let finished = try session.finish()

        XCTAssertTrue(finished.isFinal)
        XCTAssertEqual(finished.sequence, 2)
    }

    func testResetClearsState() throws {
        let session = MarkdownContract.StreamingMarkdownSession(
            engine: MarkdownnAdapter.makeEngine(),
            parseOptions: .init(documentId: "stream-doc")
        )

        _ = try session.appendChunk("abc")
        session.reset()

        let update = try session.appendChunk("x")
        XCTAssertEqual(update.sequence, 1)
        XCTAssertEqual(update.currentText, "x")
    }
}
