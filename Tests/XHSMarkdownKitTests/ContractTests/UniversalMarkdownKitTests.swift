import XCTest
@testable import XHSMarkdownKit

final class UniversalMarkdownKitTests: XCTestCase {

    func testUsesDefaultAdaptersWhenIDNotProvided() throws {
        let kit = MarkdownContract.UniversalMarkdownKit()

        let model = try kit.render("# Title")

        XCTAssertTrue(model.blocks.contains(where: { $0.kind == .heading }))
    }

    func testUsesRegisteredRendererByID() throws {
        final class StubRenderer: MarkdownContract.CanonicalRenderer {
            func render(document: MarkdownContract.CanonicalDocument, options: MarkdownContract.CanonicalRenderOptions) throws -> MarkdownContract.RenderModel {
                MarkdownContract.RenderModel(
                    documentId: document.documentId,
                    blocks: [
                        MarkdownContract.RenderBlock(
                            id: "stub",
                            kind: .custom,
                            metadata: ["stub": .bool(true)]
                        )
                    ]
                )
            }
        }

        let registry = MarkdownContract.AdapterRegistry()
        registry.registerRenderer(StubRenderer(), id: "stub.renderer")

        let kit = MarkdownContract.UniversalMarkdownKit(registry: registry)
        let model = try kit.render("# Title", rendererID: "stub.renderer")

        XCTAssertEqual(model.blocks.first?.metadata["stub"], .bool(true))
    }

    func testUnknownParserIDThrowsModelError() {
        let kit = MarkdownContract.UniversalMarkdownKit()

        XCTAssertThrowsError(try kit.render("# Title", parserID: "unknown.parser")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.path, "parserID")
        }
    }

    func testUnknownRendererIDThrowsModelError() {
        let kit = MarkdownContract.UniversalMarkdownKit()

        XCTAssertThrowsError(try kit.render("# Title", rendererID: "unknown.renderer")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.path, "rendererID")
        }
    }
}
