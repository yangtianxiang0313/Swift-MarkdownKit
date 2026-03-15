import XCTest
@testable import XHSMarkdownKit

final class SceneDeltaBuilderTests: XCTestCase {

    func testBuilderSplitsStructuralAndContentChanges() {
        let builder = DefaultSceneDeltaBuilder()

        let oldScene = makeScene(documentID: "doc", entries: [
            (id: "a", text: "Hello")
        ])
        let newScene = makeScene(documentID: "doc", entries: [
            (id: "a", text: "Hello World"),
            (id: "b", text: "New")
        ])

        let diff = SceneDiff(changes: [
            SceneChange(kind: .update, entityId: "a"),
            SceneChange(kind: .insert, entityId: "b", toIndex: 1)
        ])

        let delta = builder.makeDelta(old: oldScene, new: newScene, diff: diff)

        XCTAssertEqual(delta.structuralChanges.map(\.entityId), ["b"])
        XCTAssertEqual(Set(delta.contentChanges.map(\.entityId)), Set(["a", "b"]))

        let byID = Dictionary(uniqueKeysWithValues: delta.contentChanges.map { ($0.entityId, $0) })
        XCTAssertEqual(byID["a"]?.stableUnits, 5)
        XCTAssertEqual(byID["a"]?.targetUnits, 11)
        XCTAssertEqual(byID["b"]?.stableUnits, 0)
        XCTAssertEqual(byID["b"]?.targetUnits, 3)
    }

    private func makeScene(documentID: String, entries: [(id: String, text: String)]) -> RenderScene {
        let nodes = entries.map { entry in
            RenderScene.Node(
                id: entry.id,
                kind: "paragraph",
                component: MergedTextSceneComponent(attributedText: NSAttributedString(string: entry.text))
            )
        }
        return RenderScene(documentId: documentID, nodes: nodes)
    }
}
