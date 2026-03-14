import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class UniversalMarkdownKitTests: XCTestCase {

    func testKitHasNoDefaultAdaptersByDefault() {
        let kit = MarkdownContract.UniversalMarkdownKit()

        XCTAssertThrowsError(try kit.render("# Title")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.requiredFieldMissing.rawValue)
            XCTAssertEqual(modelError.path, "parserID")
        }
    }

    func testUsesInstalledDefaultAdaptersWhenIDNotProvided() throws {
        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        MarkdownnAdapter.install(into: registry)

        let kit = MarkdownContract.UniversalMarkdownKit(registry: registry)
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

        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        MarkdownnAdapter.install(into: registry)
        registry.registerRenderer(StubRenderer(), id: "stub.renderer")

        let kit = MarkdownContract.UniversalMarkdownKit(registry: registry)
        let model = try kit.render("# Title", rendererID: "stub.renderer")

        XCTAssertEqual(model.blocks.first?.metadata["stub"], .bool(true))
    }

    func testUnknownParserIDThrowsModelError() {
        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        MarkdownnAdapter.install(into: registry)

        let kit = MarkdownContract.UniversalMarkdownKit(registry: registry)

        XCTAssertThrowsError(try kit.render("# Title", parserID: "unknown.parser")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.path, "parserID")
        }
    }

    func testUnknownRendererIDThrowsModelError() {
        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        MarkdownnAdapter.install(into: registry)

        let kit = MarkdownContract.UniversalMarkdownKit(registry: registry)

        XCTAssertThrowsError(try kit.render("# Title", rendererID: "unknown.renderer")) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                XCTFail("Expected ModelError")
                return
            }
            XCTAssertEqual(modelError.path, "rendererID")
        }
    }
}
