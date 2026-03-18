import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public struct MarkdownRenderStreamRef: Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct MarkdownRenderStreamRecord: Sendable {
    public let ref: MarkdownRenderStreamRef
    public let documentID: String
    public let revision: Int
    public let sequence: Int
    public let isFinal: Bool
    public let currentText: String
    public let latestUpdate: MarkdownContract.StreamingRenderUpdate?

    public init(
        ref: MarkdownRenderStreamRef,
        documentID: String,
        revision: Int,
        sequence: Int,
        isFinal: Bool,
        currentText: String,
        latestUpdate: MarkdownContract.StreamingRenderUpdate?
    ) {
        self.ref = ref
        self.documentID = documentID
        self.revision = max(0, revision)
        self.sequence = max(0, sequence)
        self.isFinal = isFinal
        self.currentText = currentText
        self.latestUpdate = latestUpdate
    }
}

public struct MarkdownRenderStoreSnapshot: Sendable {
    public let revision: Int
    public let streamRecords: [MarkdownRenderStreamRef: MarkdownRenderStreamRecord]
    public let animationStates: [AnimationEntityKey: AnimationEntityProgressState]

    public init(
        revision: Int,
        streamRecords: [MarkdownRenderStreamRef: MarkdownRenderStreamRecord],
        animationStates: [AnimationEntityKey: AnimationEntityProgressState]
    ) {
        self.revision = max(0, revision)
        self.streamRecords = streamRecords
        self.animationStates = animationStates
    }

    public func streamRecord(ref: MarkdownRenderStreamRef) -> MarkdownRenderStreamRecord? {
        streamRecords[ref]
    }

    public func animationState(documentID: String, entityID: String) -> AnimationEntityProgressState? {
        animationStates[AnimationEntityKey(documentId: documentID, entityId: entityID)]
    }
}

public enum MarkdownRenderStoreEventKind: Sendable, Equatable {
    case streamCreated(ref: MarkdownRenderStreamRef)
    case streamUpdated(ref: MarkdownRenderStreamRef)
    case streamFinished(ref: MarkdownRenderStreamRef)
    case streamRemoved(ref: MarkdownRenderStreamRef)
    case animationStateChanged(key: AnimationEntityKey)
    case animationStateReset(documentID: String)
}

public struct MarkdownRenderStoreEvent: Sendable {
    public let kind: MarkdownRenderStoreEventKind
    public let snapshot: MarkdownRenderStoreSnapshot

    public init(kind: MarkdownRenderStoreEventKind, snapshot: MarkdownRenderStoreSnapshot) {
        self.kind = kind
        self.snapshot = snapshot
    }
}

public final class MarkdownRenderStoreObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    public func cancel() {
        cancellation?()
        cancellation = nil
    }

    deinit {
        cancel()
    }
}

public enum MarkdownRenderStoreError: Error, Equatable {
    case streamingEngineNotConfigured
    case streamNotFound
    case streamAlreadyFinished
}

public final class MarkdownRenderStore: AnimationStateBackingStore {
    public typealias Listener = (MarkdownRenderStoreEvent) -> Void

    private struct StreamState {
        var session: MarkdownContract.StreamingMarkdownSession
        var documentID: String
        var revision: Int
        var isFinal: Bool
        var currentText: String
        var latestUpdate: MarkdownContract.StreamingRenderUpdate?
    }

    private let defaultEngine: MarkdownContractEngine?
    private let differ: any MarkdownContract.RenderModelDiffer
    private let compiler: any MarkdownContract.RenderModelAnimationCompiler

    private var storeRevision: Int = 0
    private var streamStatesByRef: [MarkdownRenderStreamRef: StreamState] = [:]
    private var animationStateByKey: [AnimationEntityKey: AnimationEntityProgressState] = [:]

    private var listeners: [UUID: Listener] = [:]

    public init(
        engine: MarkdownContractEngine? = nil,
        differ: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer(),
        compiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler()
    ) {
        self.defaultEngine = engine
        self.differ = differ
        self.compiler = compiler
    }

    @discardableResult
    public func createStream(
        documentID: String = "document",
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions(),
        engine: MarkdownContractEngine? = nil
    ) throws -> MarkdownRenderStreamRef {
        guard let resolvedEngine = engine ?? defaultEngine else {
            throw MarkdownRenderStoreError.streamingEngineNotConfigured
        }

        let ref = MarkdownRenderStreamRef()
        var options = parseOptions
        options.documentId = documentID

        let session = MarkdownContract.StreamingMarkdownSession(
            engine: resolvedEngine,
            differ: differ,
            compiler: compiler,
            parseOptions: options,
            renderOptions: renderOptions
        )

        streamStatesByRef[ref] = StreamState(
            session: session,
            documentID: documentID,
            revision: 0,
            isFinal: false,
            currentText: "",
            latestUpdate: nil
        )
        bumpRevision()
        notify(kind: .streamCreated(ref: ref))
        return ref
    }

    @discardableResult
    public func appendChunk(
        ref: MarkdownRenderStreamRef,
        chunk: String
    ) throws -> MarkdownRenderStreamRecord {
        guard var state = streamStatesByRef[ref] else {
            throw MarkdownRenderStoreError.streamNotFound
        }
        guard !state.isFinal else {
            throw MarkdownRenderStoreError.streamAlreadyFinished
        }

        let update = try state.session.appendChunk(chunk)
        state.revision += 1
        state.currentText = update.currentText
        state.latestUpdate = update
        streamStatesByRef[ref] = state

        bumpRevision()
        notify(kind: .streamUpdated(ref: ref))
        return makeStreamRecord(ref: ref, state: state)
    }

    @discardableResult
    public func finishStream(ref: MarkdownRenderStreamRef) throws -> MarkdownRenderStreamRecord {
        guard var state = streamStatesByRef[ref] else {
            throw MarkdownRenderStoreError.streamNotFound
        }

        if state.isFinal {
            return makeStreamRecord(ref: ref, state: state)
        }

        let update = try state.session.finish()
        state.revision += 1
        state.currentText = update.currentText
        state.latestUpdate = update
        state.isFinal = true
        streamStatesByRef[ref] = state

        bumpRevision()
        notify(kind: .streamFinished(ref: ref))
        return makeStreamRecord(ref: ref, state: state)
    }

    public func streamRecord(ref: MarkdownRenderStreamRef) -> MarkdownRenderStreamRecord? {
        guard let state = streamStatesByRef[ref] else { return nil }
        return makeStreamRecord(ref: ref, state: state)
    }

    public func removeStream(ref: MarkdownRenderStreamRef) {
        guard streamStatesByRef.removeValue(forKey: ref) != nil else { return }
        bumpRevision()
        notify(kind: .streamRemoved(ref: ref))
    }

    public func removeStreams(documentID: String) {
        let keys = streamStatesByRef.compactMap { key, value in
            value.documentID == documentID ? key : nil
        }
        guard !keys.isEmpty else { return }
        for key in keys {
            streamStatesByRef.removeValue(forKey: key)
        }
        bumpRevision()
        notify(kind: .animationStateReset(documentID: documentID))
    }

    public func removeAllStreams() {
        guard !streamStatesByRef.isEmpty else { return }
        streamStatesByRef.removeAll()
        bumpRevision()
        notify(kind: .animationStateReset(documentID: "*"))
    }

    public func snapshot() -> MarkdownRenderStoreSnapshot {
        makeSnapshot()
    }

    @discardableResult
    public func observe(listener: @escaping Listener) -> MarkdownRenderStoreObservation {
        let token = UUID()
        listeners[token] = listener
        listener(MarkdownRenderStoreEvent(kind: .animationStateReset(documentID: "initial"), snapshot: makeSnapshot()))

        return MarkdownRenderStoreObservation { [weak self] in
            self?.listeners.removeValue(forKey: token)
        }
    }

    public func prepareAnimationState(
        documentID: String,
        revealUnitsByEntity: [String: Int]
    ) {
        var changed = false

        let keysForDocument = animationStateByKey.keys.filter { $0.documentId == documentID }
        let activeEntitySet = Set(revealUnitsByEntity.keys)

        for key in keysForDocument where !activeEntitySet.contains(key.entityId) {
            animationStateByKey.removeValue(forKey: key)
            changed = true
        }

        for (entityID, maxUnitsRaw) in revealUnitsByEntity {
            let key = AnimationEntityKey(documentId: documentID, entityId: entityID)
            guard let existing = animationStateByKey[key] else { continue }

            let maxUnits = max(0, maxUnitsRaw)
            let clamped = AnimationEntityProgressState(
                displayedUnits: min(maxUnits, max(0, existing.displayedUnits)),
                stableUnits: min(maxUnits, max(0, existing.stableUnits)),
                targetUnits: min(maxUnits, max(0, existing.targetUnits)),
                lastVersion: existing.lastVersion
            )

            if clamped != existing {
                animationStateByKey[key] = clamped
                changed = true
            }
        }

        guard changed else { return }
        bumpRevision()
        notify(kind: .animationStateReset(documentID: documentID))
    }

    public func animationState(for key: AnimationEntityKey) -> AnimationEntityProgressState? {
        animationStateByKey[key]
    }

    public func animationStates(documentID: String) -> [AnimationEntityKey: AnimationEntityProgressState] {
        animationStateByKey.filter { $0.key.documentId == documentID }
    }

    public func setAnimationState(_ state: AnimationEntityProgressState, for key: AnimationEntityKey) {
        if animationStateByKey[key] == state {
            return
        }
        animationStateByKey[key] = state
        bumpRevision()
        notify(kind: .animationStateChanged(key: key))
    }

    public func removeAnimationStates(documentID: String) {
        let keys = animationStateByKey.keys.filter { $0.documentId == documentID }
        guard !keys.isEmpty else { return }
        for key in keys {
            animationStateByKey.removeValue(forKey: key)
        }
        bumpRevision()
        notify(kind: .animationStateReset(documentID: documentID))
    }
}

private extension MarkdownRenderStore {
    private func makeStreamRecord(ref: MarkdownRenderStreamRef, state: StreamState) -> MarkdownRenderStreamRecord {
        MarkdownRenderStreamRecord(
            ref: ref,
            documentID: state.documentID,
            revision: state.revision,
            sequence: state.latestUpdate?.sequence ?? 0,
            isFinal: state.isFinal,
            currentText: state.currentText,
            latestUpdate: state.latestUpdate
        )
    }

    private func makeSnapshot() -> MarkdownRenderStoreSnapshot {
        let records = Dictionary(uniqueKeysWithValues: streamStatesByRef.map { key, state in
            (key, makeStreamRecord(ref: key, state: state))
        })
        return MarkdownRenderStoreSnapshot(
            revision: storeRevision,
            streamRecords: records,
            animationStates: animationStateByKey
        )
    }

    private func bumpRevision() {
        storeRevision += 1
    }

    private func notify(kind: MarkdownRenderStoreEventKind) {
        guard !listeners.isEmpty else { return }
        let event = MarkdownRenderStoreEvent(kind: kind, snapshot: makeSnapshot())
        for listener in listeners.values {
            listener(event)
        }
    }
}
