import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

final class NodeExtensionDescriptorTests: XCTestCase {

    func testDescriptorRegistryInstallsStructureAndBehaviorTogether() throws {
        let thinkKind: MarkdownContract.NodeKind = .ext(.init(namespace: "spec", name: "think"))
        let descriptor = MarkdownContract.NodeExtensionDescriptor(
            id: "think",
            tag: .init(
                tagName: "Think",
                nodeKind: thinkKind,
                role: .blockContainer,
                childPolicy: .blockOnly(minChildren: 0),
                pairingMode: .paired
            ),
            behavior: .init(
                kind: thinkKind,
                stateSlots: ["collapsed": .bool(false)],
                actionMappings: ["activate": "toggle"],
                stateKeyPolicy: .auto
            )
        )

        let extensionRegistry = try MarkdownContract.NodeExtensionRegistry(descriptors: [descriptor])
        let nodeSpecs = MarkdownContract.NodeSpecRegistry.core()
        extensionRegistry.installStructure(into: nodeSpecs)

        let behaviorRegistry = MarkdownContract.NodeBehaviorRegistry()
        extensionRegistry.installBehavior(into: behaviorRegistry)

        XCTAssertEqual(nodeSpecs.resolveKind(sourceKind: .htmlTag, name: "think"), thinkKind)
        XCTAssertEqual(nodeSpecs.tagPairingMode(forHTMLTagName: "think"), .paired)
        XCTAssertEqual(behaviorRegistry.schema(for: thinkKind)?.actionMappings["activate"], "toggle")
    }

    func testDecodeDescriptorArrayFromJSONAndParseCustomNodes() throws {
        let json = """
        [
          {
            "id": "mention",
            "tag": {
              "tagName": "mention",
              "nodeKind": "ext.json.mention",
              "role": "inlineLeaf",
              "childPolicy": {
                "type": "none"
              },
              "pairingMode": "selfClosing"
            },
            "behavior": {
              "kind": "ext.json.mention",
              "stateSlots": {},
              "actionMappings": {
                "activate": "activate"
              },
              "effectSpecs": [],
              "stateKeyPolicy": "auto"
            }
          },
          {
            "id": "think",
            "tag": {
              "tagName": "think",
              "nodeKind": "ext.json.think",
              "role": "blockContainer",
              "childPolicy": {
                "type": "blockOnly",
                "minChildren": 0
              },
              "pairingMode": "paired"
            },
            "behavior": {
              "kind": "ext.json.think",
              "stateSlots": {
                "collapsed": false
              },
              "actionMappings": {
                "activate": "toggle"
              },
              "effectSpecs": [],
              "stateKeyPolicy": "auto"
            }
          }
        ]
        """

        let descriptors = try MarkdownContract.JSONModelCodec.decodeNodeExtensionDescriptors(from: Data(json.utf8))
        let nodeSpecs = MarkdownContract.NodeSpecRegistry.core()
        try nodeSpecs.registerExtensionDescriptors(descriptors)

        let parser = XYMarkdownContractParser(nodeSpecRegistry: nodeSpecs)
        let document = try parser.parse(
            """
            <Think id="x">
            - a
            - b
            </Think>

            before <mention userId="u1" /> after
            """,
            options: .init(documentId: "json-descriptor-doc")
        )
        let allNodes = flatten(document.root)

        XCTAssertTrue(allNodes.contains(where: { $0.kind.rawValue == "ext.json.think" }))
        XCTAssertTrue(allNodes.contains(where: { $0.kind.rawValue == "ext.json.mention" }))
        XCTAssertTrue(allNodes.contains(where: { node in
            node.kind == .text && node.attrs["text"] == .string("a")
        }))
    }

    func testDescriptorValidationRejectsMismatchedKinds() {
        let descriptor = MarkdownContract.NodeExtensionDescriptor(
            id: "mismatch",
            tag: .init(
                tagName: "think",
                nodeKind: .ext(.init(namespace: "x", name: "think")),
                role: .blockContainer,
                childPolicy: .blockOnly(minChildren: 0),
                pairingMode: .paired
            ),
            behavior: .init(
                kind: .ext(.init(namespace: "x", name: "other")),
                stateSlots: ["collapsed": .bool(false)],
                actionMappings: [:],
                effectSpecs: [],
                stateKeyPolicy: .auto
            )
        )

        XCTAssertThrowsError(try descriptor.validate()) { error in
            guard let modelError = error as? MarkdownContract.ModelError else {
                return XCTFail("Expected ModelError")
            }
            XCTAssertEqual(modelError.code, MarkdownContract.ModelError.Code.schemaInvalid.rawValue)
            XCTAssertEqual(modelError.path, "behavior.kind")
        }
    }
}

private extension NodeExtensionDescriptorTests {
    func flatten(_ root: MarkdownContract.CanonicalNode) -> [MarkdownContract.CanonicalNode] {
        var result: [MarkdownContract.CanonicalNode] = [root]
        for child in root.children {
            result.append(contentsOf: flatten(child))
        }
        return result
    }
}
