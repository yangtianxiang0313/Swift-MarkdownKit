import XCTest
import UIKit
@testable import XHSMarkdownKit

@MainActor
final class RenderCommitCoordinatorTests: XCTestCase {

    func testLatestWinsKeepsDisplayedUnitsOnInterruptedStreamingUpdate() {
        let host = SceneHost()
        let coordinator = host.makeCoordinator()
        coordinator.concurrencyPolicy = .latestWins

        let firstTarget = makeScene(documentID: "doc", text: "abcdefghij", entityID: "text")
        let firstFrame = makeFrame(
            version: 1,
            previousScene: .empty(documentId: "doc"),
            targetScene: firstTarget,
            diffChanges: [SceneChange(kind: .insert, entityId: "text", toIndex: 0)],
            contentChanges: [ContentSceneChange(entityId: "text", stableUnits: 0, targetUnits: 10, inserted: true)],
            unitsPerSecond: 24
        )
        coordinator.submit(firstFrame)

        runMainLoop(for: 0.14)
        let displayedBeforeInterrupt = host.displayedUnits(for: "text")
        XCTAssertGreaterThan(displayedBeforeInterrupt, 0)
        XCTAssertLessThan(displayedBeforeInterrupt, 10)

        let secondTarget = makeScene(documentID: "doc", text: "abcdefghijkl", entityID: "text")
        let secondFrame = makeFrame(
            version: 2,
            previousScene: firstTarget,
            targetScene: secondTarget,
            diffChanges: [SceneChange(kind: .update, entityId: "text")],
            // Simulate an upstream delta that reports full old target as stable.
            contentChanges: [ContentSceneChange(entityId: "text", stableUnits: 10, targetUnits: 12, inserted: false)],
            unitsPerSecond: 24
        )
        coordinator.submit(secondFrame)

        let displayedAfterInterrupt = host.displayedUnits(for: "text")
        XCTAssertGreaterThanOrEqual(
            displayedAfterInterrupt,
            displayedBeforeInterrupt,
            "latestWins should continue from current visible progress"
        )
        XCTAssertLessThanOrEqual(
            displayedAfterInterrupt,
            displayedBeforeInterrupt + 1,
            "latestWins should not jump to upstream stableUnits when runtime progress is behind"
        )
    }

    func testCompletedAnimationLeavesNoFadedTailCharacters() {
        let host = SceneHost()
        let coordinator = host.makeCoordinator()
        coordinator.concurrencyPolicy = .fullyOrdered

        let completion = expectation(description: "animation completed")
        coordinator.onAnimationComplete = {
            completion.fulfill()
        }

        let target = makeScene(documentID: "doc", text: "abcdef", entityID: "text")
        let frame = makeFrame(
            version: 1,
            previousScene: .empty(documentId: "doc"),
            targetScene: target,
            diffChanges: [SceneChange(kind: .insert, entityId: "text", toIndex: 0)],
            contentChanges: [ContentSceneChange(entityId: "text", stableUnits: 0, targetUnits: 6, inserted: true)],
            unitsPerSecond: 120
        )
        coordinator.submit(frame)

        wait(for: [completion], timeout: 1.0)

        guard let rendered = host.renderedText(for: "text") else {
            XCTFail("Expected rendered text view content")
            return
        }
        XCTAssertEqual(rendered.string.count, 6)

        for index in 0..<rendered.length {
            let color = rendered.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor
            let alpha = color?.cgColor.alpha ?? 1
            XCTAssertGreaterThanOrEqual(alpha, 0.995, "index \(index) should be fully opaque")
        }
    }

    func testSimultaneousAppearanceModeRevealsMultipleEntitiesTogether() {
        let sequentialHost = SceneHost()
        let sequentialCoordinator = sequentialHost.makeCoordinator()
        sequentialCoordinator.concurrencyPolicy = .fullyOrdered

        let simultaneousHost = SceneHost()
        let simultaneousCoordinator = simultaneousHost.makeCoordinator()
        simultaneousCoordinator.concurrencyPolicy = .fullyOrdered

        let target = RenderScene(
            documentId: "doc",
            nodes: [
                .init(
                    id: "a",
                    kind: "paragraph",
                    component: MergedTextSceneComponent(attributedText: NSAttributedString(string: "abcdefghij"))
                ),
                .init(
                    id: "b",
                    kind: "paragraph",
                    component: MergedTextSceneComponent(attributedText: NSAttributedString(string: "abcdefghij"))
                )
            ]
        )

        let contentChanges = [
            ContentSceneChange(entityId: "a", stableUnits: 0, targetUnits: 10, inserted: true),
            ContentSceneChange(entityId: "b", stableUnits: 0, targetUnits: 10, inserted: true)
        ]

        sequentialCoordinator.submit(makeFrame(
            version: 1,
            previousScene: .empty(documentId: "doc"),
            targetScene: target,
            diffChanges: [
                SceneChange(kind: .insert, entityId: "a", toIndex: 0),
                SceneChange(kind: .insert, entityId: "b", toIndex: 1)
            ],
            contentChanges: contentChanges,
            unitsPerSecond: 24,
            entityAppearanceMode: .sequential
        ))

        simultaneousCoordinator.submit(makeFrame(
            version: 1,
            previousScene: .empty(documentId: "doc"),
            targetScene: target,
            diffChanges: [
                SceneChange(kind: .insert, entityId: "a", toIndex: 0),
                SceneChange(kind: .insert, entityId: "b", toIndex: 1)
            ],
            contentChanges: contentChanges,
            unitsPerSecond: 24,
            entityAppearanceMode: .simultaneous
        ))

        runMainLoop(for: 0.14)

        let seqA = sequentialHost.displayedUnits(for: "a")
        let seqB = sequentialHost.displayedUnits(for: "b")
        XCTAssertGreaterThan(seqA, 0)
        XCTAssertEqual(seqB, 0)

        let simA = simultaneousHost.displayedUnits(for: "a")
        let simB = simultaneousHost.displayedUnits(for: "b")
        XCTAssertGreaterThan(simA, 0)
        XCTAssertGreaterThan(simB, 0)
    }

    func testSwitchingDocumentResetsSidecarProgressForSameEntityID() {
        let host = SceneHost()
        let coordinator = host.makeCoordinator()
        coordinator.concurrencyPolicy = .fullyOrdered

        let completion = expectation(description: "first animation completed")
        coordinator.onAnimationComplete = {
            completion.fulfill()
        }

        let firstTarget = makeScene(documentID: "doc-A", text: "abcdefghij", entityID: "text")
        coordinator.submit(makeFrame(
            version: 1,
            previousScene: .empty(documentId: "doc-A"),
            targetScene: firstTarget,
            diffChanges: [SceneChange(kind: .insert, entityId: "text", toIndex: 0)],
            contentChanges: [ContentSceneChange(entityId: "text", stableUnits: 0, targetUnits: 10, inserted: true)],
            unitsPerSecond: 120
        ))

        wait(for: [completion], timeout: 1.0)
        let displayedInDocA = host.displayedUnits(for: "text")
        XCTAssertEqual(displayedInDocA, 10)

        let secondTarget = makeScene(documentID: "doc-B", text: "abcdefghij", entityID: "text")
        coordinator.submit(makeFrame(
            version: 2,
            previousScene: .empty(documentId: "doc-B"),
            targetScene: secondTarget,
            diffChanges: [SceneChange(kind: .insert, entityId: "text", toIndex: 0)],
            contentChanges: [ContentSceneChange(entityId: "text", stableUnits: 0, targetUnits: 10, inserted: true)],
            unitsPerSecond: 24
        ))

        let displayedAfterSwitch = host.displayedUnits(for: "text")
        XCTAssertLessThan(displayedAfterSwitch, 5)
    }

    func testInsertedStandaloneEntityMountsOnlyWhenItsRevealStarts() {
        let host = SceneHost()
        let coordinator = host.makeCoordinator()
        coordinator.concurrencyPolicy = .fullyOrdered

        let completion = expectation(description: "animation completed")
        coordinator.onAnimationComplete = {
            completion.fulfill()
        }

        let target = RenderScene(
            documentId: "doc",
            nodes: [
                .init(
                    id: "text",
                    kind: "paragraph",
                    component: MergedTextSceneComponent(attributedText: NSAttributedString(string: "abcdefghij"))
                ),
                .init(
                    id: "code",
                    kind: "codeBlock",
                    component: CodeBlockSceneComponent(
                        code: "0123456789",
                        language: "swift",
                        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                        textColor: .label,
                        backgroundColor: .secondarySystemBackground,
                        cornerRadius: 8,
                        padding: .init(top: 8, left: 8, bottom: 8, right: 8),
                        borderWidth: 0,
                        borderColor: .clear
                    )
                )
            ]
        )
        let structural = [
            StructuralSceneChange(kind: .insert, entityId: "text", toIndex: 0),
            StructuralSceneChange(kind: .insert, entityId: "code", toIndex: 1)
        ]
        let content = [
            ContentSceneChange(entityId: "text", stableUnits: 0, targetUnits: 10, inserted: true),
            ContentSceneChange(entityId: "code", stableUnits: 0, targetUnits: 10, inserted: true)
        ]
        let plan = RenderExecutionPlan(stages: [
            .init(
                id: "structure",
                phase: .structure,
                effectKey: .segmentFade,
                structuralChanges: structural
            ),
            .init(
                id: "content",
                phase: .content,
                effectKey: .typing,
                contentChanges: content
            )
        ])

        let frame = RenderFrame(
            version: 1,
            previousScene: .empty(documentId: "doc"),
            targetScene: target,
            diff: SceneDiff(changes: [
                SceneChange(kind: .insert, entityId: "text", toIndex: 0),
                SceneChange(kind: .insert, entityId: "code", toIndex: 1)
            ]),
            delta: SceneDelta(structuralChanges: structural, contentChanges: content),
            executionPlan: plan,
            isFinal: false,
            animationMode: .dualPhase,
            defaultEffectKey: .typing,
            entityAppearanceMode: .sequential,
            unitsPerSecond: 24
        )
        coordinator.submit(frame)

        runMainLoop(for: 0.18)
        XCTAssertTrue(host.hasView(for: "text"))
        XCTAssertFalse(host.hasView(for: "code"))

        wait(for: [completion], timeout: 2.0)
        XCTAssertTrue(host.hasView(for: "code"))
    }

    private func runMainLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func makeScene(documentID: String, text: String, entityID: String) -> RenderScene {
        RenderScene(
            documentId: documentID,
            nodes: [
                .init(
                    id: entityID,
                    kind: "paragraph",
                    component: MergedTextSceneComponent(attributedText: NSAttributedString(string: text))
                )
            ]
        )
    }

    private func makeFrame(
        version: Int,
        previousScene: RenderScene,
        targetScene: RenderScene,
        diffChanges: [SceneChange],
        contentChanges: [ContentSceneChange],
        unitsPerSecond: Int,
        effectKey: AnimationEffectKey = .typing,
        entityAppearanceMode: ContentEntityAppearanceMode = .sequential
    ) -> RenderFrame {
        RenderFrame(
            version: version,
            previousScene: previousScene,
            targetScene: targetScene,
            diff: SceneDiff(changes: diffChanges),
            delta: SceneDelta(structuralChanges: [], contentChanges: contentChanges),
            executionPlan: nil,
            isFinal: false,
            animationMode: .dualPhase,
            defaultEffectKey: effectKey,
            entityAppearanceMode: entityAppearanceMode,
            unitsPerSecond: unitsPerSecond
        )
    }
}

@MainActor
private final class SceneHost {
    private let containerView = UIView()
    private let viewGraphCoordinator: ViewGraphCoordinator
    private let animationStateStore = MarkdownRenderStore()

    init() {
        containerView.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        viewGraphCoordinator = ViewGraphCoordinator(containerView: containerView)
    }

    func makeCoordinator() -> RenderCommitCoordinator {
        RenderCommitCoordinator(
            applyScene: { [weak self] scene in
                guard let self else { return }
                _ = self.viewGraphCoordinator.apply(scene: scene, maxWidth: 320)
            },
            viewForEntity: { [weak self] entityID in
                self?.viewGraphCoordinator.view(for: entityID)
            },
            measureHeight: { [weak self] in
                guard let self else { return 0 }
                return self.containerView.subviews.map { $0.frame.maxY }.max() ?? 0
            },
            animateStructuralChanges: { _ in },
            animationStateStore: animationStateStore
        )
    }

    func renderedText(for entityID: String) -> NSAttributedString? {
        guard let root = viewGraphCoordinator.view(for: entityID) else { return nil }
        return findTextView(in: root)?.attributedText
    }

    func hasView(for entityID: String) -> Bool {
        viewGraphCoordinator.view(for: entityID) != nil
    }

    func displayedUnits(for entityID: String) -> Int {
        renderedText(for: entityID)?.string.count ?? 0
    }

    private func findTextView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView {
            return textView
        }
        for child in view.subviews {
            if let found = findTextView(in: child) {
                return found
            }
        }
        return nil
    }
}
