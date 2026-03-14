import XCTest
@testable import XHSMarkdownKit

final class ContractAnimationPlanMapperTests: XCTestCase {

    func testMapperRespectsTimelineConstraintsAndPhaseGrouping() {
        let mapper = DefaultContractAnimationPlanMapper()

        let oldScene = makeScene(documentID: "doc", entries: [
            (id: "a", text: "A"),
            (id: "b", text: "old")
        ])
        let newScene = makeScene(documentID: "doc", entries: [
            (id: "b", text: "new"),
            (id: "c", text: "C")
        ])

        let diff = SceneDiff(changes: [
            SceneChange(kind: .remove, entityId: "a", fromIndex: 0),
            SceneChange(kind: .move, entityId: "b", fromIndex: 1, toIndex: 0),
            SceneChange(kind: .insert, entityId: "c", toIndex: 1),
            SceneChange(kind: .update, entityId: "b")
        ])

        let plan = mapper.makePlan(
            contractPlan: .init(
                intents: [],
                timeline: .init(
                    tracks: [
                        .init(id: "t.remove", entityIds: ["a"], metadata: ["changeType": .string("remove")]),
                        .init(id: "t.move", entityIds: ["b"], metadata: ["changeType": .string("move")]),
                        .init(id: "t.insert", entityIds: ["c"], metadata: ["changeType": .string("insert")]),
                        .init(id: "t.update", entityIds: ["b"], metadata: ["changeType": .string("update")])
                    ],
                    phases: [
                        .init(
                            id: "content",
                            name: "content",
                            trackIds: ["t.update"],
                            metadata: ["effectKey": .string("typing")]
                        ),
                        .init(
                            id: "structure",
                            name: "structure",
                            trackIds: ["t.remove", "t.move", "t.insert"]
                        )
                    ],
                    constraints: [
                        .init(kind: "after", from: "structure", to: "content")
                    ]
                )
            ),
            oldScene: oldScene,
            newScene: newScene,
            diff: diff,
            defaultEffectKey: .instant
        )

        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(plan.steps[0].id, "contract.structure.0")
        XCTAssertEqual(Set(plan.steps[0].entityIDs), Set(["a", "b", "c"]))
        XCTAssertEqual(plan.steps[0].effectKey, .instant)

        XCTAssertEqual(plan.steps[1].id, "contract.content.1")
        XCTAssertEqual(plan.steps[1].entityIDs, ["b"])
        XCTAssertEqual(plan.steps[1].effectKey, .typing)
        XCTAssertEqual(plan.steps[1].dependencies, [plan.steps[0].id])
    }

    func testMapperFallsBackWhenTimelineHasNoPhases() {
        let mapper = DefaultContractAnimationPlanMapper()

        let oldScene = RenderScene.empty(documentId: "doc")
        let newScene = makeScene(documentID: "doc", entries: [(id: "x", text: "X")])
        let diff = SceneDiff(changes: [
            SceneChange(kind: .insert, entityId: "x", toIndex: 0)
        ])

        let plan = mapper.makePlan(
            contractPlan: .init(
                intents: [],
                timeline: .init(tracks: [], phases: [], constraints: [])
            ),
            oldScene: oldScene,
            newScene: newScene,
            diff: diff,
            defaultEffectKey: .segmentFade
        )

        XCTAssertEqual(plan.steps.count, 1)
        XCTAssertEqual(plan.steps[0].id, "contract.remainder")
        XCTAssertEqual(plan.steps[0].effectKey, .segmentFade)
        XCTAssertEqual(plan.steps[0].entityIDs, ["x"])
    }

    private func makeScene(documentID: String, entries: [(id: String, text: String)]) -> RenderScene {
        let nodes = entries.map { entry in
            RenderScene.Node(
                id: entry.id,
                kind: "paragraph",
                component: TextSceneComponent(attributedText: NSAttributedString(string: entry.text))
            )
        }
        return RenderScene(documentId: documentID, nodes: nodes)
    }
}
