import XCTest
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

@MainActor
final class MarkdownRuntimeTests: XCTestCase {

    func testRuntimeSetInputAndToggleCollapseUpdatesSceneAndRevision() throws {
        let model = try MarkdownnAdapter.makeEngine().render("> quoted")
        guard let blockQuote = model.blocks.first(where: { $0.kind == .blockQuote }) else {
            XCTFail("blockQuote missing")
            return
        }

        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let runtime = MarkdownRuntime()
        runtime.attach(to: view)
        try runtime.setInput(.renderModel(model))

        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).contains("quoted"))

        runtime.dispatch(
            MarkdownEvent(
                documentID: model.documentId,
                nodeID: blockQuote.id,
                nodeKind: .blockQuote,
                stateKey: blockQuote.id,
                action: "toggle",
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )

        XCTAssertGreaterThan(runtime.stateSnapshot.revision, 0)
        XCTAssertFalse(mergedText(from: view.currentSceneSnapshot).contains("quoted"))
    }

    func testRuntimeToggleCollapseWorksForExtensionBlockContainer() throws {
        let thinkKind: MarkdownContract.NodeKind = .ext(.init(namespace: "runtime", name: "think"))
        let model = MarkdownContract.RenderModel(
            documentId: "doc-think-runtime",
            blocks: [
                .init(
                    id: "think-1",
                    kind: thinkKind,
                    children: [
                        .init(
                            id: "think-paragraph",
                            kind: .paragraph,
                            inlines: [.init(id: "think-text", kind: .text, text: "thinking-body")]
                        )
                    ],
                    metadata: ["id": .string("think-state-1")]
                )
            ]
        )

        let behaviorRegistry = MarkdownContract.NodeBehaviorRegistry(
            schemas: [
                .init(
                    kind: thinkKind,
                    stateSlots: ["collapsed": .bool(false)],
                    actionMappings: ["activate": "toggle"],
                    stateKeyPolicy: .auto
                )
            ]
        )

        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        let adapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )
        view.contractRenderAdapter = adapter

        let runtime = MarkdownRuntime(behaviorRegistry: behaviorRegistry)
        runtime.attach(to: view)
        try runtime.setInput(.renderModel(model))
        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).contains("thinking-body"))

        runtime.dispatch(
            MarkdownEvent(
                documentID: "doc-think-runtime",
                nodeID: "think-1",
                nodeKind: thinkKind,
                stateKey: "think-state-1",
                action: "toggle",
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )

        XCTAssertFalse(mergedText(from: view.currentSceneSnapshot).contains("thinking-body"))
        XCTAssertEqual(runtime.stateStore.value(stateKey: "think-state-1", slot: "collapsed"), .bool(true))
    }

    func testHandledDecisionDoesNotBlockReducer() throws {
        let model = try MarkdownnAdapter.makeEngine().render("> quoted")
        guard let blockQuote = model.blocks.first(where: { $0.kind == .blockQuote }) else {
            XCTFail("blockQuote missing")
            return
        }

        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let runtime = MarkdownRuntime()
        runtime.eventHandler = { _ in .handled }
        runtime.attach(to: view)
        try runtime.setInput(.renderModel(model))

        let before = runtime.stateSnapshot.revision
        runtime.dispatch(
            MarkdownEvent(
                documentID: model.documentId,
                nodeID: blockQuote.id,
                nodeKind: .blockQuote,
                stateKey: blockQuote.id,
                action: "toggle",
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )

        XCTAssertGreaterThan(runtime.stateSnapshot.revision, before)
    }

    func testRuntimeLoadsAndSavesSnapshotViaPersistenceAdapter() throws {
        let model = try MarkdownnAdapter.makeEngine().render("> quoted")
        guard let blockQuote = model.blocks.first(where: { $0.kind == .blockQuote }) else {
            XCTFail("blockQuote missing")
            return
        }

        let persisted = MarkdownStateSnapshot(
            documentID: model.documentId,
            revision: 1,
            nodeStates: [blockQuote.id: ["collapsed": .bool(true)]]
        )
        let persistence = RuntimePersistenceAdapter()
        persistence.loadedSnapshots[model.documentId] = persisted

        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let behaviorRegistry = MarkdownContract.NodeBehaviorRegistry(
            schemas: [
                .init(
                    kind: .blockQuote,
                    stateSlots: ["collapsed": .bool(false)],
                    stateKeyPolicy: .nodeID
                )
            ]
        )
        let runtime = MarkdownRuntime(
            behaviorRegistry: behaviorRegistry,
            stateStore: MarkdownStateStore(),
            effectRunner: MarkdownEffectRunner()
        )
        runtime.persistenceAdapter = persistence
        runtime.attach(to: view)
        try runtime.setInput(.renderModel(model))

        XCTAssertFalse(mergedText(from: view.currentSceneSnapshot).contains("quoted"))

        runtime.dispatch(
            MarkdownEvent(
                documentID: model.documentId,
                nodeID: blockQuote.id,
                nodeKind: .blockQuote,
                stateKey: blockQuote.id,
                action: "toggle",
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )
        XCTAssertGreaterThan(persistence.saveCount, 0)
    }

    func testCopyEventSchedulesResetEffect() throws {
        let clock = RuntimeEffectTestClock()
        let runner = MarkdownEffectRunner(clock: clock)
        let runtime = MarkdownRuntime(
            stateStore: MarkdownStateStore(),
            effectRunner: runner
        )

        let model = MarkdownContract.RenderModel(
            documentId: "doc-copy",
            blocks: [
                .init(
                    id: "code1",
                    kind: .codeBlock,
                    metadata: ["code": .string("print(1)")]
                )
            ]
        )

        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        runtime.attach(to: view)
        try runtime.setInput(MarkdownRuntimeInput.renderModel(model))

        XCTAssertEqual(codeBlockCopyStatus(in: view.currentSceneSnapshot, nodeID: "code1"), "idle")

        runtime.dispatch(
            MarkdownEvent(
                documentID: "doc-copy",
                nodeID: "code1",
                nodeKind: .codeBlock,
                stateKey: "code1",
                action: "copy",
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )

        if case let .string(value)? = runtime.stateStore.value(stateKey: "code1", slot: "copyStatus") {
            XCTAssertEqual(value, "copied")
        } else {
            XCTFail("copyStatus should be copied")
        }
        XCTAssertEqual(codeBlockCopyStatus(in: view.currentSceneSnapshot, nodeID: "code1"), "copied")

        clock.fireAll()

        if case let .string(value)? = runtime.stateStore.value(stateKey: "code1", slot: "copyStatus") {
            XCTAssertEqual(value, "idle")
        } else {
            XCTFail("copyStatus should be idle")
        }
        XCTAssertEqual(codeBlockCopyStatus(in: view.currentSceneSnapshot, nodeID: "code1"), "idle")
    }

    func testStaleEffectIsDiscardedWhenRevisionChanges() throws {
        let clock = RuntimeEffectTestClock()
        let runner = MarkdownEffectRunner(clock: clock)
        let runtime = MarkdownRuntime(
            stateStore: MarkdownStateStore(),
            effectRunner: runner
        )

        let model = MarkdownContract.RenderModel(
            documentId: "doc-copy-stale",
            blocks: [
                .init(
                    id: "code1",
                    kind: .codeBlock,
                    metadata: ["code": .string("print(1)")]
                )
            ]
        )

        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        runtime.attach(to: view)
        try runtime.setInput(.renderModel(model))

        runtime.dispatch(
            MarkdownEvent(
                documentID: "doc-copy-stale",
                nodeID: "code1",
                nodeKind: .codeBlock,
                stateKey: "code1",
                action: "copy",
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )

        runtime.dispatch(
            MarkdownEvent(
                documentID: "doc-copy-stale",
                nodeID: "code1",
                nodeKind: .codeBlock,
                stateKey: "code1",
                action: "set",
                payload: [
                    "slot": .string("dummy"),
                    "value": .int(1)
                ],
                origin: .user,
                revision: runtime.stateSnapshot.revision
            )
        )

        clock.fireAll()

        if case let .string(value)? = runtime.stateStore.value(stateKey: "code1", slot: "copyStatus") {
            XCTAssertEqual(value, "copied")
        } else {
            XCTFail("copyStatus should stay copied when stale reset is dropped")
        }
    }

    func testFinishStreamWithUnchangedModelDoesNotTriggerAdditionalRenderPass() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        let delegate = RuntimeContainerDelegateSpy()
        view.delegate = delegate

        let runtime = MarkdownRuntime(streamingEngine: MarkdownnAdapter.makeEngine())
        runtime.attach(to: view)

        let ref = try runtime.startStream(documentID: "doc.runtime.finish.stable")
        try runtime.appendStreamChunk(ref: ref, chunk: "Hello world")

        let sceneAfterAppend = view.currentSceneSnapshot
        let heightEventsAfterAppend = delegate.heightEvents.count
        XCTAssertGreaterThan(heightEventsAfterAppend, 0)

        try runtime.finishStream(ref: ref)

        XCTAssertEqual(delegate.heightEvents.count, heightEventsAfterAppend)
        XCTAssertEqual(view.currentSceneSnapshot, sceneAfterAppend)
    }

    func testAttachWithoutCurrentModelClearsReusedContainerScene() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)

        let firstRuntime = MarkdownRuntime(streamingEngine: MarkdownnAdapter.makeEngine())
        firstRuntime.attach(to: view)
        let firstRef = try firstRuntime.startStream(documentID: "doc.runtime.reuse.1")
        try firstRuntime.appendStreamChunk(ref: firstRef, chunk: "Hello")
        try firstRuntime.finishStream(ref: firstRef)

        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).contains("Hello"))
        firstRuntime.cancelStream(ref: firstRef)
        firstRuntime.detach()

        let secondRuntime = MarkdownRuntime(streamingEngine: MarkdownnAdapter.makeEngine())
        secondRuntime.attach(to: view)

        XCTAssertTrue(mergedText(from: view.currentSceneSnapshot).isEmpty)
        XCTAssertGreaterThanOrEqual(view.contentHeight, 1)
    }

    func testSingleChunkStreamingCodeBlockStillAnimatesHeightProgressively() throws {
        let view = MarkdownContainerView(theme: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        view.setAnimationPreset(.typing(charactersPerSecond: 10))

        let delegate = RuntimeContainerDelegateSpy()
        view.delegate = delegate

        let runtime = MarkdownRuntime(streamingEngine: MarkdownnAdapter.makeEngine())
        runtime.attach(to: view)

        let codeBody = (1...10).map { "p\($0)" }.joined(separator: "\n")
        let markdown = """
        ```swift
        \(codeBody)
        ```
        """

        let ref = try runtime.startStream(documentID: "doc.runtime.single-chunk.code")
        try runtime.appendStreamChunk(ref: ref, chunk: markdown)

        let reachedEarly = waitUntil(timeout: 2.0) {
            delegate.heightEvents.count > 0 && view.contentHeight > 0
        }
        XCTAssertTrue(reachedEarly)
        let earlyHeight = view.contentHeight

        try runtime.finishStream(ref: ref)

        let completed = waitUntil(timeout: 5.0) {
            delegate.animationCompletionCount > 0
        }
        XCTAssertTrue(completed)

        let finalHeight = view.contentHeight
        XCTAssertLessThan(earlyHeight, finalHeight)
        XCTAssertGreaterThan(delegate.heightEvents.count, 2)
        runtime.cancelStream(ref: ref)
    }
}

@MainActor
private final class RuntimePersistenceAdapter: MarkdownStatePersistenceAdapter {
    var loadedSnapshots: [String: MarkdownStateSnapshot] = [:]
    var saveCount: Int = 0

    func load(documentID: String) -> MarkdownStateSnapshot? {
        loadedSnapshots[documentID]
    }

    func save(documentID: String, snapshot: MarkdownStateSnapshot) {
        saveCount += 1
        loadedSnapshots[documentID] = snapshot
    }
}

private final class RuntimeEffectTestClock: MarkdownEffectClock {
    private var tasks: [UUID: () -> Void] = [:]

    @discardableResult
    func schedule(afterMilliseconds delayMilliseconds: Int, task: @escaping () -> Void) -> any MarkdownEffectToken {
        let id = UUID()
        tasks[id] = task
        return RuntimeEffectTestToken { [weak self] in
            self?.tasks.removeValue(forKey: id)
        }
    }

    func fireAll() {
        let all = tasks.values
        tasks.removeAll()
        for task in all {
            task()
        }
    }
}

private final class RuntimeEffectTestToken: MarkdownEffectToken {
    private let cancelBlock: () -> Void

    init(cancelBlock: @escaping () -> Void) {
        self.cancelBlock = cancelBlock
    }

    func cancel() {
        cancelBlock()
    }
}

private final class RuntimeContainerDelegateSpy: MarkdownContainerViewDelegate {
    private(set) var heightEvents: [CGFloat] = []
    private(set) var animationCompletionCount: Int = 0

    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        heightEvents.append(height)
    }

    func containerViewDidCompleteAnimation(_ view: MarkdownContainerView) {
        animationCompletionCount += 1
    }
}

private func codeBlockCopyStatus(in scene: RenderScene, nodeID: String) -> String? {
    guard let node = scene.flattenRenderableNodes().first(where: { $0.id == nodeID }),
          let component = node.component as? CodeBlockSceneComponent else {
        return nil
    }
    return component.copyStatus
}

@MainActor
private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    return condition()
}
