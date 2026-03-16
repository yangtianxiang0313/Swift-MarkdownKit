import XCTest
@testable import XHSMarkdownKit

final class ContractAnimationPlanMapperTests: XCTestCase {

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

    func testMapperRespectsAfterConstraintWithStructureThenContent() {
        let mapper = DefaultContractAnimationPlanMapper()
        let contractPlan = MarkdownContract.CompiledAnimationPlan(
            intents: [],
            timeline: MarkdownContract.TimelineGraph(
                tracks: [
                    .init(id: "track.insert", entityIds: ["b"], metadata: ["changeType": .string("insert")]),
                    .init(id: "track.update", entityIds: ["a"], metadata: ["changeType": .string("update")])
                ],
                phases: [
                    .init(id: "phase.structure", name: "structure", trackIds: ["track.insert"], metadata: ["effectKey": .string("segmentFade")]),
                    .init(id: "phase.content", name: "content", trackIds: ["track.update"], metadata: ["effectKey": .string("typing")])
                ],
                constraints: [
                    .init(kind: "after", from: "phase.structure", to: "phase.content")
                ]
            )
        )

        let plan = mapper.makePlan(
            contractPlan: contractPlan,
            delta: SceneDelta(
                structuralChanges: [.init(kind: .insert, entityId: "b", toIndex: 1)],
                contentChanges: [.init(entityId: "a", stableUnits: 5, targetUnits: 11, inserted: false)]
            ),
            defaultEffectKey: .typing
        )

        XCTAssertEqual(plan.stages.count, 2)
        XCTAssertEqual(plan.stages[0].phase, .structure)
        XCTAssertEqual(plan.stages[1].phase, .content)
        XCTAssertEqual(plan.stages[0].effectKey, .segmentFade)
        XCTAssertEqual(plan.stages[1].effectKey, .typing)
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
