import XCTest
@testable import XHSMarkdownKit

final class ContractAnimationPlanMapperTests: XCTestCase {

    func testMapperRespectsTimelineConstraintsAndPhaseGrouping() {
        let mapper = DefaultContractAnimationPlanMapper()

        let a = MapperTestFragment(id: "a", payload: "A")
        let bOld = MapperTestFragment(id: "b", payload: "old")
        let bNew = MapperTestFragment(id: "b", payload: "new")
        let c = MapperTestFragment(id: "c", payload: "C")

        let oldFragments: [RenderFragment] = [a, bOld]
        let newFragments: [RenderFragment] = [bNew, c]
        let changes: [FragmentChange] = [
            .remove(fragmentId: "a", at: 0),
            .move(fragmentId: "b", from: 1, to: 0),
            .insert(fragment: c, at: 1),
            .update(old: bOld, new: bNew, childChanges: nil)
        ]

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
            oldFragments: oldFragments,
            newFragments: newFragments,
            changes: changes,
            defaultEffectKey: .instant
        )

        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertTrue(plan.steps[0].changes.contains(where: isStructureChange))
        XCTAssertFalse(plan.steps[0].changes.contains(where: isUpdateChange))
        XCTAssertTrue(plan.steps[1].changes.contains(where: isUpdateChange))
        XCTAssertEqual(plan.steps[1].effectKey, .typing)
    }

    func testMapperFallsBackWhenTimelineHasNoPhases() {
        let mapper = DefaultContractAnimationPlanMapper()

        let newFragment = MapperTestFragment(id: "x", payload: "X")
        let changes: [FragmentChange] = [
            .insert(fragment: newFragment, at: 0)
        ]

        let plan = mapper.makePlan(
            contractPlan: .init(
                intents: [],
                timeline: .init(tracks: [], phases: [], constraints: [])
            ),
            oldFragments: [],
            newFragments: [newFragment],
            changes: changes,
            defaultEffectKey: .segmentFade
        )

        XCTAssertEqual(plan.steps.count, 1)
        XCTAssertEqual(plan.steps[0].id, "contract.remainder")
        XCTAssertEqual(plan.steps[0].effectKey, .segmentFade)
    }

    private func isStructureChange(_ change: FragmentChange) -> Bool {
        switch change {
        case .insert, .remove, .move:
            return true
        case .update:
            return false
        }
    }

    private func isUpdateChange(_ change: FragmentChange) -> Bool {
        if case .update = change { return true }
        return false
    }
}

private final class MapperTestFragment: RenderFragment {
    let fragmentId: String
    let nodeType: FragmentNodeType = .paragraph
    var spacingAfter: CGFloat = 0

    private let payload: String

    init(id: String, payload: String) {
        self.fragmentId = id
        self.payload = payload
    }

    func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? MapperTestFragment else { return false }
        guard fragmentId == rhs.fragmentId else { return false }
        guard spacingAfter == rhs.spacingAfter else { return false }
        return payload == rhs.payload
    }
}
