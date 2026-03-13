import XCTest
@testable import XHSMarkdownKit

final class RendererRegistryTests: XCTestCase {

    func testCustomParagraphRendererOverridesDefault() {
        let registry = RendererRegistry.makeDefault()
        registry.register(FixedTextRenderer(text: "OVERRIDDEN"), for: .paragraph)

        let fragments = render("original paragraph", registry: registry)
        let text = mergedText(from: fragments)

        XCTAssertTrue(text.contains("OVERRIDDEN"))
        XCTAssertFalse(text.contains("original paragraph"))
    }

    func testRemoveCustomRendererFallsBackToDefault() {
        let registry = RendererRegistry.makeDefault()
        registry.register(FixedTextRenderer(text: "OVERRIDDEN"), for: .paragraph)
        registry.removeCustomRenderer(for: .paragraph)

        let fragments = render("original paragraph", registry: registry)
        let text = mergedText(from: fragments)

        XCTAssertTrue(text.contains("original paragraph"))
        XCTAssertFalse(text.contains("OVERRIDDEN"))
    }
}
