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
        XCTAssertFalse(first.compiledAnimationPlan.timeline.phases.isEmpty)

        let second = try session.appendChunk(" world")
        XCTAssertEqual(second.sequence, 2)
        XCTAssertEqual(second.currentText, "Hello world")
        XCTAssertTrue(second.model.blocks.contains(where: { $0.kind == .paragraph }))
        XCTAssertGreaterThanOrEqual(second.compiledAnimationPlan.intents.count, second.diff.flattenedChanges.count)
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

    func testStreamingSessionCoversCustomNodesAndSpecialFormatsAcrossChunks() throws {
        let descriptors: [MarkdownContract.NodeExtensionDescriptor] = [
            .init(
                id: "mention",
                tag: .init(
                    tagName: "mention",
                    nodeKind: .ext(.init(namespace: "stream", name: "mention")),
                    role: .inlineLeaf,
                    childPolicy: .none,
                    pairingMode: .selfClosing
                )
            ),
            .init(
                id: "cite",
                tag: .init(
                    tagName: "cite",
                    nodeKind: .ext(.init(namespace: "stream", name: "cite")),
                    role: .inlineContainer,
                    childPolicy: .inlineOnly(minChildren: 0),
                    pairingMode: .paired
                )
            ),
            .init(
                id: "think",
                tag: .init(
                    tagName: "think",
                    nodeKind: .ext(.init(namespace: "stream", name: "think")),
                    role: .blockContainer,
                    childPolicy: .blockOnly(minChildren: 0),
                    pairingMode: .paired
                )
            )
        ]

        let nodeSpecs = MarkdownContract.NodeSpecRegistry.core()
        try nodeSpecs.registerExtensionDescriptors(descriptors)
        let parser = XYMarkdownContractParser(nodeSpecRegistry: nodeSpecs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: .makeDefault(),
            nodeSpecRegistry: nodeSpecs
        )
        let engine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: nodeSpecs),
            renderer: renderer
        )
        let session = MarkdownContract.StreamingMarkdownSession(
            engine: engine,
            parseOptions: .init(documentId: "stream-full-coverage")
        )

        let chunks = [
            "<Think id=\"think-1\">\n- step1 ~~done~~\n",
            "- step2 `code` and [link](https://example.com)\n</Think>\n\n",
            "before <mention userId=\"alice\" /> and <Cite id=\"c-1\">ref-1</Cite>\n\n```swift\nprint(1)\n```\n\n| k | v |\n| --- | --- |\n| a | b |\n"
        ]

        var updates: [MarkdownContract.StreamingRenderUpdate] = []
        for chunk in chunks {
            updates.append(try session.appendChunk(chunk))
        }
        let finalUpdate = try session.finish()

        XCTAssertEqual(updates.map(\.sequence), [1, 2, 3])
        XCTAssertEqual(finalUpdate.sequence, 4)
        XCTAssertTrue(finalUpdate.isFinal)
        XCTAssertEqual(finalUpdate.currentText, chunks.joined())

        let allNodes = flatten(finalUpdate.document.root)
        XCTAssertTrue(allNodes.contains(where: { $0.kind.rawValue == "ext.stream.think" }))
        XCTAssertTrue(allNodes.contains(where: { $0.kind.rawValue == "ext.stream.mention" }))
        XCTAssertTrue(allNodes.contains(where: { $0.kind.rawValue == "ext.stream.cite" }))
        XCTAssertTrue(allNodes.contains(where: { node in
            node.kind == .text && node.attrs["text"] == .string("ref-1")
        }))

        XCTAssertTrue(finalUpdate.model.blocks.contains(where: { $0.kind.rawValue == "ext.stream.think" }))
        XCTAssertTrue(finalUpdate.model.blocks.contains(where: { $0.kind == .codeBlock }))
        XCTAssertTrue(finalUpdate.model.blocks.contains(where: { $0.kind == .table }))
        XCTAssertTrue(allInlines(in: finalUpdate.model.blocks).contains(where: { span in
            span.marks.contains(where: { $0.name == "strikethrough" })
        }))
    }

    func testStreamingSessionWithJSONDeliveredDescriptors() throws {
        let descriptorJSON = """
        [
          {
            "id": "think",
            "tag": {
              "tagName": "think",
              "nodeKind": "ext.streamjson.think",
              "role": "blockContainer",
              "childPolicy": {
                "type": "blockOnly",
                "minChildren": 0
              },
              "pairingMode": "paired"
            }
          }
        ]
        """
        let descriptors = try MarkdownContract.JSONModelCodec.decodeNodeExtensionDescriptors(from: Data(descriptorJSON.utf8))
        let nodeSpecs = MarkdownContract.NodeSpecRegistry.core()
        try nodeSpecs.registerExtensionDescriptors(descriptors)

        let parser = XYMarkdownContractParser(nodeSpecRegistry: nodeSpecs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: .makeDefault(),
            nodeSpecRegistry: nodeSpecs
        )
        let engine = MarkdownContractEngine(
            parser: parser,
            rewritePipeline: .init(nodeSpecRegistry: nodeSpecs),
            renderer: renderer
        )
        let session = MarkdownContract.StreamingMarkdownSession(
            engine: engine,
            parseOptions: .init(documentId: "stream-json-descriptor")
        )

        _ = try session.appendChunk("<Think id=\"json-think\">\njson payload\n")
        let final = try session.appendChunk("</Think>\n")
        XCTAssertFalse(final.isFinal)
        XCTAssertTrue(flatten(final.document.root).contains(where: { $0.kind.rawValue == "ext.streamjson.think" }))
    }

}

private extension StreamingMarkdownSessionTests {
    func flatten(_ root: MarkdownContract.CanonicalNode) -> [MarkdownContract.CanonicalNode] {
        var result: [MarkdownContract.CanonicalNode] = [root]
        for child in root.children {
            result.append(contentsOf: flatten(child))
        }
        return result
    }

    func allInlines(in blocks: [MarkdownContract.RenderBlock]) -> [MarkdownContract.InlineSpan] {
        blocks.flatMap { block in
            block.inlines + allInlines(in: block.children)
        }
    }
}
