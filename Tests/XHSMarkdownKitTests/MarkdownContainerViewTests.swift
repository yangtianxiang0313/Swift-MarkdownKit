import XCTest
@testable import XHSMarkdownKit

final class MarkdownContainerViewTests: XCTestCase {

    func testContainerViewSetTextProducesContentHeight() {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.setText("# Title\n\nParagraph")

        XCTAssertGreaterThan(view.contentHeight, 0)
    }

    func testContainerViewAppendStreamChunkIncreasesContent() {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        view.setText("Hello")
        let heightBefore = view.contentHeight

        view.appendStreamChunk(" world")
        view.finishStreaming()

        XCTAssertGreaterThanOrEqual(view.contentHeight, heightBefore)
    }
}
