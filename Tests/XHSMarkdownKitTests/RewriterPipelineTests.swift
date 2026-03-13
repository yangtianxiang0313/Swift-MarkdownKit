import XCTest
@testable import XHSMarkdownKit

final class RewriterPipelineTests: XCTestCase {

    func testRewriterCanReplaceAstWithEmptyDocument() {
        let pipeline = RewriterPipeline(rewriters: [{ _ in
            EmptyDocumentNode()
        }])

        let fragments = render("# Title\n\nBody", rewriterPipeline: pipeline)

        XCTAssertTrue(fragments.isEmpty)
    }

    func testIdentityRewriterKeepsOutput() {
        let baseline = render("# Title")
        let pipeline = RewriterPipeline(rewriters: [{ $0 }])
        let rewritten = render("# Title", rewriterPipeline: pipeline)

        XCTAssertEqual(mergedText(from: rewritten), mergedText(from: baseline))
    }
}
