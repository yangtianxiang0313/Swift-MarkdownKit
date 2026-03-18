import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public struct MarkdownStreamRef: Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct MarkdownStreamTimePoint: Sendable, Equatable {
    public let seconds: TimeInterval

    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    public static var now: MarkdownStreamTimePoint {
        MarkdownStreamTimePoint(seconds: ProcessInfo.processInfo.systemUptime)
    }
}

public struct MarkdownStreamAnimatedRange: Sendable, Equatable {
    public let start: Int
    public let end: Int
    public let birthTimeSeconds: TimeInterval
    public let durationSeconds: TimeInterval
    public let progress: Double

    public init(
        start: Int,
        end: Int,
        birthTimeSeconds: TimeInterval,
        durationSeconds: TimeInterval,
        progress: Double
    ) {
        self.start = max(0, start)
        self.end = max(self.start, end)
        self.birthTimeSeconds = birthTimeSeconds
        self.durationSeconds = max(0.001, durationSeconds)
        self.progress = min(1, max(0, progress))
    }
}

public struct MarkdownStreamSnapshot: Sendable {
    public let ref: MarkdownStreamRef
    public let revision: Int
    public let isFinal: Bool
    public let textLength: Int
    public let animatedRanges: [MarkdownStreamAnimatedRange]

    public init(
        ref: MarkdownStreamRef,
        revision: Int,
        isFinal: Bool,
        textLength: Int,
        animatedRanges: [MarkdownStreamAnimatedRange]
    ) {
        self.ref = ref
        self.revision = max(0, revision)
        self.isFinal = isFinal
        self.textLength = max(0, textLength)
        self.animatedRanges = animatedRanges
    }
}

public struct MarkdownStreamEvent: Sendable {
    public let snapshot: MarkdownStreamSnapshot
    public let latestUpdate: MarkdownContract.StreamingRenderUpdate?

    public init(
        snapshot: MarkdownStreamSnapshot,
        latestUpdate: MarkdownContract.StreamingRenderUpdate?
    ) {
        self.snapshot = snapshot
        self.latestUpdate = latestUpdate
    }
}

public final class MarkdownStreamObservation {
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

public enum MarkdownStreamStoreError: Error, Equatable {
    case streamNotFound
    case streamAlreadyFinished
}

@MainActor
public final class MarkdownStreamStore {
    public typealias Listener = (MarkdownStreamEvent) -> Void

    private struct BirthRange {
        var start: Int
        var end: Int
        var birthTimeSeconds: TimeInterval
        var durationSeconds: TimeInterval
    }

    private struct StreamState {
        var session: MarkdownContract.StreamingMarkdownSession
        var revision: Int
        var isFinal: Bool
        var textLength: Int
        var latestUpdate: MarkdownContract.StreamingRenderUpdate?
        var birthRanges: [BirthRange]
        var listeners: [UUID: Listener]
    }

    private let engine: MarkdownContractEngine
    private let differ: any MarkdownContract.RenderModelDiffer
    private let compiler: any MarkdownContract.RenderModelAnimationCompiler
    private let defaultRangeDurationSeconds: TimeInterval

    private var statesByRef: [MarkdownStreamRef: StreamState] = [:]

    public init(
        engine: MarkdownContractEngine,
        differ: any MarkdownContract.RenderModelDiffer = MarkdownContract.DefaultRenderModelDiffer(),
        compiler: any MarkdownContract.RenderModelAnimationCompiler = MarkdownContract.DefaultRenderModelAnimationCompiler(),
        defaultRangeDurationSeconds: TimeInterval = 0.75
    ) {
        self.engine = engine
        self.differ = differ
        self.compiler = compiler
        self.defaultRangeDurationSeconds = max(0.001, defaultRangeDurationSeconds)
    }

    @discardableResult
    public func createStream(
        documentID: String? = nil,
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    ) -> MarkdownStreamRef {
        let ref = MarkdownStreamRef()
        var options = parseOptions
        if let documentID, !documentID.isEmpty {
            options.documentId = documentID
        }

        let session = MarkdownContract.StreamingMarkdownSession(
            engine: engine,
            differ: differ,
            compiler: compiler,
            parseOptions: options,
            renderOptions: renderOptions
        )

        statesByRef[ref] = StreamState(
            session: session,
            revision: 0,
            isFinal: false,
            textLength: 0,
            latestUpdate: nil,
            birthRanges: [],
            listeners: [:]
        )
        return ref
    }

    @discardableResult
    public func append(
        ref: MarkdownStreamRef,
        chunk: String,
        at: MarkdownStreamTimePoint = .now
    ) throws -> MarkdownStreamEvent {
        guard var state = statesByRef[ref] else {
            throw MarkdownStreamStoreError.streamNotFound
        }
        guard !state.isFinal else {
            throw MarkdownStreamStoreError.streamAlreadyFinished
        }

        let oldLength = state.textLength
        let update = try state.session.appendChunk(chunk)
        state.revision += 1
        state.textLength = update.currentText.count
        state.latestUpdate = update

        if state.textLength > oldLength {
            state.birthRanges.append(
                BirthRange(
                    start: oldLength,
                    end: state.textLength,
                    birthTimeSeconds: at.seconds,
                    durationSeconds: defaultRangeDurationSeconds
                )
            )
        }

        let snapshot = makeSnapshot(ref: ref, state: &state, at: at)
        statesByRef[ref] = state
        let event = MarkdownStreamEvent(snapshot: snapshot, latestUpdate: state.latestUpdate)
        notify(event: event, listeners: state.listeners)
        return event
    }

    @discardableResult
    public func finish(
        ref: MarkdownStreamRef,
        at: MarkdownStreamTimePoint = .now
    ) throws -> MarkdownStreamEvent {
        guard var state = statesByRef[ref] else {
            throw MarkdownStreamStoreError.streamNotFound
        }
        guard !state.isFinal else {
            let snapshot = makeSnapshot(ref: ref, state: &state, at: at)
            statesByRef[ref] = state
            return MarkdownStreamEvent(snapshot: snapshot, latestUpdate: state.latestUpdate)
        }

        let update = try state.session.finish()
        state.revision += 1
        state.textLength = update.currentText.count
        state.latestUpdate = update
        state.isFinal = true

        let snapshot = makeSnapshot(ref: ref, state: &state, at: at)
        statesByRef[ref] = state
        let event = MarkdownStreamEvent(snapshot: snapshot, latestUpdate: state.latestUpdate)
        notify(event: event, listeners: state.listeners)
        return event
    }

    public func snapshot(
        ref: MarkdownStreamRef,
        at: MarkdownStreamTimePoint = .now
    ) throws -> MarkdownStreamSnapshot {
        guard var state = statesByRef[ref] else {
            throw MarkdownStreamStoreError.streamNotFound
        }
        let snapshot = makeSnapshot(ref: ref, state: &state, at: at)
        statesByRef[ref] = state
        return snapshot
    }

    @discardableResult
    public func observe(
        ref: MarkdownStreamRef,
        listener: @escaping Listener
    ) throws -> MarkdownStreamObservation {
        guard var state = statesByRef[ref] else {
            throw MarkdownStreamStoreError.streamNotFound
        }
        let token = UUID()
        state.listeners[token] = listener
        let snapshot = makeSnapshot(ref: ref, state: &state, at: .now)
        statesByRef[ref] = state
        listener(MarkdownStreamEvent(snapshot: snapshot, latestUpdate: state.latestUpdate))

        return MarkdownStreamObservation { [weak self] in
            guard let self else { return }
            self.removeListener(ref: ref, token: token)
        }
    }

    public func removeStream(ref: MarkdownStreamRef) {
        statesByRef.removeValue(forKey: ref)
    }
}

@MainActor
private extension MarkdownStreamStore {
    func removeListener(ref: MarkdownStreamRef, token: UUID) {
        guard var state = statesByRef[ref] else { return }
        state.listeners.removeValue(forKey: token)
        statesByRef[ref] = state
    }

    private func makeSnapshot(
        ref: MarkdownStreamRef,
        state: inout StreamState,
        at timePoint: MarkdownStreamTimePoint
    ) -> MarkdownStreamSnapshot {
        state.birthRanges = state.birthRanges.filter { range in
            let elapsed = max(0, timePoint.seconds - range.birthTimeSeconds)
            return elapsed < range.durationSeconds
        }

        let ranges = state.birthRanges.map { range in
            let elapsed = max(0, timePoint.seconds - range.birthTimeSeconds)
            let progress = min(1, elapsed / range.durationSeconds)
            return MarkdownStreamAnimatedRange(
                start: range.start,
                end: range.end,
                birthTimeSeconds: range.birthTimeSeconds,
                durationSeconds: range.durationSeconds,
                progress: progress
            )
        }

        return MarkdownStreamSnapshot(
            ref: ref,
            revision: state.revision,
            isFinal: state.isFinal,
            textLength: state.textLength,
            animatedRanges: ranges
        )
    }

    func notify(event: MarkdownStreamEvent, listeners: [UUID: Listener]) {
        for listener in listeners.values {
            listener(event)
        }
    }
}
