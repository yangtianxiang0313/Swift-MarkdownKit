import XCTest
@testable import XHSMarkdownKit

final class MarkdownContractTests: XCTestCase {

    func testCanonicalDocumentRoundTrip() throws {
        let root = MarkdownContract.CanonicalNode(
            id: "root",
            kind: .document,
            children: [
                MarkdownContract.CanonicalNode(
                    id: "p1",
                    kind: .paragraph,
                    attrs: ["align": .string("left")],
                    children: [],
                    source: MarkdownContract.SourceInfo(sourceKind: .markdown, raw: "hello")
                )
            ],
            source: MarkdownContract.SourceInfo(sourceKind: .markdown)
        )
        let document = MarkdownContract.CanonicalDocument(documentId: "doc-1", root: root)

        let data = try MarkdownContract.JSONModelCodec.encodeCanonicalDocument(document)
        let decoded = try MarkdownContract.JSONModelCodec.decodeCanonicalDocument(from: data)

        XCTAssertEqual(decoded, document)
    }

    func testRenderModelRoundTrip() throws {
        let model = MarkdownContract.RenderModel(
            documentId: "doc-1",
            blocks: [
                MarkdownContract.RenderBlock(
                    id: "b1",
                    kind: .paragraph,
                    inlines: [
                        MarkdownContract.InlineSpan(id: "i1", kind: .text, text: "hello")
                    ],
                    styleTokens: [
                        MarkdownContract.StyleToken(
                            name: "text.color",
                            value: .color(.init(token: "text.primary"))
                        ),
                        MarkdownContract.StyleToken(
                            name: "text.size",
                            value: .number(16)
                        )
                    ]
                )
            ],
            assets: [
                MarkdownContract.RenderAsset(id: "a1", type: "image", source: "https://example.com/a.png")
            ]
        )

        let data = try MarkdownContract.JSONModelCodec.encodeRenderModel(model)
        let decoded = try MarkdownContract.JSONModelCodec.decodeRenderModel(from: data)

        XCTAssertEqual(decoded, model)
    }

    func testAnimationDTORoundTrip() throws {
        let snapshot = MarkdownContract.SceneSnapshot(
            sceneId: "scene-1",
            entities: [
                MarkdownContract.SceneEntity(
                    id: "e1",
                    kind: "block",
                    frame: .init(x: 0, y: 0, width: 100, height: 24)
                )
            ],
            layoutTree: .init(id: "e1")
        )

        let snapshotData = try MarkdownContract.JSONModelCodec.encodeSceneSnapshot(snapshot)
        let decodedSnapshot = try MarkdownContract.JSONModelCodec.decodeSceneSnapshot(from: snapshotData)
        XCTAssertEqual(decodedSnapshot, snapshot)

        let graph = MarkdownContract.TimelineGraph(
            tracks: [.init(id: "t1", entityIds: ["e1"])],
            phases: [.init(id: "p1", name: "enter", trackIds: ["t1"])],
            constraints: [.init(kind: "after", from: "p0", to: "p1")]
        )

        let graphData = try MarkdownContract.JSONModelCodec.encodeTimelineGraph(graph)
        let decodedGraph = try MarkdownContract.JSONModelCodec.decodeTimelineGraph(from: graphData)
        XCTAssertEqual(decodedGraph, graph)

        let progress = MarkdownContract.AnimationProgress(
            version: 1,
            running: true,
            completedSteps: 1,
            totalSteps: 3,
            displayedUnits: 12,
            totalUnits: 30
        )
        let progressData = try JSONEncoder().encode(progress)
        let decodedProgress = try JSONDecoder().decode(MarkdownContract.AnimationProgress.self, from: progressData)
        XCTAssertEqual(decodedProgress, progress)
    }

    func testUnsupportedVersionReturnsModelError() throws {
        let payload = """
        {
          "schemaVersion": 999,
          "documentId": "doc-1",
          "root": {
            "id": "root",
            "kind": "document",
            "attrs": {},
            "children": [],
            "source": { "sourceKind": "markdown" },
            "metadata": {}
          },
          "metadata": {}
        }
        """.data(using: .utf8)!

        do {
            _ = try MarkdownContract.JSONModelCodec.decodeCanonicalDocument(from: payload)
            XCTFail("Expected unsupported_version")
        } catch let error as MarkdownContract.ModelError {
            XCTAssertEqual(error.code, MarkdownContract.ModelError.Code.unsupportedVersion.rawValue)
        }
    }

    func testInvalidColorValueReturnsModelError() throws {
        let model = MarkdownContract.RenderModel(
            documentId: "doc-1",
            blocks: [
                MarkdownContract.RenderBlock(
                    id: "b1",
                    kind: .paragraph,
                    styleTokens: [
                        MarkdownContract.StyleToken(
                            name: "text.color",
                            value: .color(.init())
                        )
                    ]
                )
            ]
        )

        do {
            _ = try MarkdownContract.JSONModelCodec.encodeRenderModel(model)
            XCTFail("Expected invalid_style_value")
        } catch let error as MarkdownContract.ModelError {
            XCTAssertEqual(error.code, MarkdownContract.ModelError.Code.invalidStyleValue.rawValue)
        }
    }

    func testUnknownFieldsPreserved() throws {
        let payload = """
        {
          "schemaVersion": 1,
          "documentId": "doc-unknown",
          "topExtra": { "type": "string", "value": "top" },
          "root": {
            "id": "root",
            "kind": "document",
            "attrs": {},
            "children": [],
            "source": {
              "sourceKind": "markdown",
              "sourceExtra": { "type": "int", "value": 42 }
            },
            "nodeExtra": { "type": "bool", "value": true },
            "metadata": {}
          },
          "metadata": {}
        }
        """.data(using: .utf8)!

        let doc = try MarkdownContract.JSONModelCodec.decodeCanonicalDocument(from: payload)
        XCTAssertEqual(doc.additionalFields["topExtra"], .string("top"))
        XCTAssertEqual(doc.root.additionalFields["nodeExtra"], .bool(true))
        XCTAssertEqual(doc.root.source.additionalFields["sourceExtra"], .int(42))

        let data = try MarkdownContract.JSONModelCodec.encodeCanonicalDocument(doc)
        let decoded = try MarkdownContract.JSONModelCodec.decodeCanonicalDocument(from: data)
        XCTAssertEqual(decoded.additionalFields["topExtra"], .string("top"))
    }

    func testContractLayerHasNoPlatformImports() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let projectRoot = thisFile
            .deletingLastPathComponent() // ContractTests
            .deletingLastPathComponent() // XHSMarkdownKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // project root

        let contractDir = projectRoot.appendingPathComponent("Sources/XHSMarkdownKit/Contract")
        let files = try FileManager.default.contentsOfDirectory(at: contractDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        XCTAssertFalse(files.isEmpty)

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(content.contains("import UIKit"), "UIKit import found in \(file.path)")
            XCTAssertFalse(content.contains("import SwiftUI"), "SwiftUI import found in \(file.path)")
            XCTAssertFalse(content.contains("import AppKit"), "AppKit import found in \(file.path)")
        }
    }
}
