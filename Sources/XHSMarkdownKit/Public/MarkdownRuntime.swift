import Foundation
import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public enum MarkdownRuntimeInput {
    case markdown(
        text: String,
        documentID: String = "document",
        parserID: MarkdownContract.ParserID? = nil,
        rendererID: MarkdownContract.RendererID? = nil,
        parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
        rewritePipeline: MarkdownContract.CanonicalRewritePipeline = MarkdownContract.CanonicalRewritePipeline(),
        renderOptions: MarkdownContract.CanonicalRenderOptions = MarkdownContract.CanonicalRenderOptions()
    )
    case renderModel(MarkdownContract.RenderModel)
}

public enum MarkdownEventDecision: Sendable, Equatable {
    case continueDefault
    case handled
}

public struct MarkdownEventNodeContext: Sendable, Equatable {
    public var documentID: String
    public var nodeID: String
    public var nodeKind: MarkdownContract.NodeKind
    public var nodeMetadata: [String: MarkdownContract.Value]
    public var stateKey: String
    public var payload: [String: MarkdownContract.Value]

    public init(
        documentID: String,
        nodeID: String,
        nodeKind: MarkdownContract.NodeKind,
        nodeMetadata: [String: MarkdownContract.Value],
        stateKey: String,
        payload: [String: MarkdownContract.Value] = [:]
    ) {
        self.documentID = documentID
        self.nodeID = nodeID
        self.nodeKind = nodeKind
        self.nodeMetadata = nodeMetadata
        self.stateKey = stateKey
        self.payload = payload
    }
}

public struct MarkdownEvent: Sendable, Equatable {
    public enum Origin: String, Sendable, Equatable, Codable {
        case user
        case effect
        case system
    }

    public var eventID: String
    public var documentID: String
    public var nodeID: String
    public var nodeKind: MarkdownContract.NodeKind
    public var stateKey: String
    public var action: String
    public var payload: [String: MarkdownContract.Value]
    public var associatedData: [String: MarkdownContract.Value]
    public var origin: Origin
    public var revision: Int
    public var timestampMS: Int64

    public init(
        eventID: String = UUID().uuidString,
        documentID: String,
        nodeID: String,
        nodeKind: MarkdownContract.NodeKind,
        stateKey: String,
        action: String,
        payload: [String: MarkdownContract.Value] = [:],
        associatedData: [String: MarkdownContract.Value] = [:],
        origin: Origin,
        revision: Int,
        timestampMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.eventID = eventID
        self.documentID = documentID
        self.nodeID = nodeID
        self.nodeKind = nodeKind
        self.stateKey = stateKey
        self.action = action
        self.payload = payload
        self.associatedData = associatedData
        self.origin = origin
        self.revision = revision
        self.timestampMS = timestampMS
    }
}

public struct MarkdownStateSnapshot: Sendable, Equatable, Codable {
    public var documentID: String
    public var revision: Int
    public var nodeStates: [String: [String: MarkdownContract.Value]]

    public init(
        documentID: String,
        revision: Int = 0,
        nodeStates: [String: [String: MarkdownContract.Value]] = [:]
    ) {
        self.documentID = documentID
        self.revision = max(0, revision)
        self.nodeStates = nodeStates
    }
}

@MainActor
public protocol MarkdownStatePersistenceAdapter: AnyObject {
    func load(documentID: String) -> MarkdownStateSnapshot?
    func save(documentID: String, snapshot: MarkdownStateSnapshot)
}

@MainActor
public protocol MarkdownDataBindingAdapter: AnyObject {
    func resolveAssociatedData(
        for context: MarkdownEventNodeContext,
        businessContext: [String: MarkdownContract.Value]
    ) -> [String: MarkdownContract.Value]
}

public protocol MarkdownEffectToken: AnyObject {
    func cancel()
}

public protocol MarkdownEffectClock {
    @discardableResult
    func schedule(afterMilliseconds delayMilliseconds: Int, task: @escaping () -> Void) -> any MarkdownEffectToken
}

public final class DispatchQueueEffectClock: MarkdownEffectClock {
    public init() {}

    @discardableResult
    public func schedule(afterMilliseconds delayMilliseconds: Int, task: @escaping () -> Void) -> any MarkdownEffectToken {
        let workItem = DispatchWorkItem(block: task)
        let delay = DispatchTimeInterval.milliseconds(max(0, delayMilliseconds))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return DispatchQueueEffectToken(workItem: workItem)
    }
}

public final class DispatchQueueEffectToken: MarkdownEffectToken {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    public func cancel() {
        workItem.cancel()
    }
}

@MainActor
public final class MarkdownEffectRunner {
    private let clock: any MarkdownEffectClock
    private var tokensByKey: [String: any MarkdownEffectToken] = [:]

    public init(clock: any MarkdownEffectClock = DispatchQueueEffectClock()) {
        self.clock = clock
    }

    public func schedule(
        key: String,
        delayMilliseconds: Int,
        task: @escaping () -> Void
    ) {
        cancel(key: key)
        tokensByKey[key] = clock.schedule(afterMilliseconds: delayMilliseconds) { [weak self] in
            guard let self else { return }
            self.tokensByKey.removeValue(forKey: key)
            task()
        }
    }

    public func cancel(key: String) {
        tokensByKey[key]?.cancel()
        tokensByKey.removeValue(forKey: key)
    }

    public func cancelAll() {
        for token in tokensByKey.values {
            token.cancel()
        }
        tokensByKey.removeAll()
    }
}

@MainActor
public final class MarkdownStateStore {
    public private(set) var snapshot: MarkdownStateSnapshot

    public init(snapshot: MarkdownStateSnapshot = MarkdownStateSnapshot(documentID: "document")) {
        self.snapshot = snapshot
    }

    public func replace(with snapshot: MarkdownStateSnapshot) {
        self.snapshot = snapshot
    }

    public func reset(documentID: String) {
        snapshot = MarkdownStateSnapshot(documentID: documentID)
    }

    public func value(stateKey: String, slot: String) -> MarkdownContract.Value? {
        snapshot.nodeStates[stateKey]?[slot]
    }

    public func values(stateKey: String) -> [String: MarkdownContract.Value] {
        snapshot.nodeStates[stateKey] ?? [:]
    }

    @discardableResult
    public func set(stateKey: String, slot: String, value: MarkdownContract.Value) -> Bool {
        var entry = snapshot.nodeStates[stateKey] ?? [:]
        if entry[slot] == value {
            return false
        }
        entry[slot] = value
        snapshot.nodeStates[stateKey] = entry
        snapshot.revision += 1
        return true
    }

    @discardableResult
    public func ensureDefaults(stateKey: String, defaults: [String: MarkdownContract.Value]) -> Bool {
        guard !defaults.isEmpty else { return false }

        var entry = snapshot.nodeStates[stateKey] ?? [:]
        var changed = false
        for (slot, value) in defaults where entry[slot] == nil {
            entry[slot] = value
            changed = true
        }
        guard changed else { return false }
        snapshot.nodeStates[stateKey] = entry
        snapshot.revision += 1
        return true
    }

    @discardableResult
    public func toggleBool(stateKey: String, slot: String, defaultValue: Bool = false) -> Bool {
        let current: Bool
        if case let .bool(value)? = snapshot.nodeStates[stateKey]?[slot] {
            current = value
        } else {
            current = defaultValue
        }
        return set(stateKey: stateKey, slot: slot, value: .bool(!current))
    }
}

@MainActor
public final class MarkdownRuntime {
    public var eventHandler: ((MarkdownEvent) -> MarkdownEventDecision)?
    public weak var persistenceAdapter: (any MarkdownStatePersistenceAdapter)?
    public weak var dataBindingAdapter: (any MarkdownDataBindingAdapter)?

    public let behaviorRegistry: MarkdownContract.NodeBehaviorRegistry
    public let stateStore: MarkdownStateStore
    public let effectRunner: MarkdownEffectRunner

    public var stateSnapshot: MarkdownStateSnapshot {
        stateStore.snapshot
    }

    private weak var containerView: MarkdownContainerView?
    private let stateProjector = MarkdownStateProjector()
    private var currentRawModel: MarkdownContract.RenderModel?
    private var businessContext: [String: MarkdownContract.Value] = [:]
    private var preparedDocumentID: String?

    public init(
        behaviorRegistry: MarkdownContract.NodeBehaviorRegistry? = nil,
        stateStore: MarkdownStateStore,
        effectRunner: MarkdownEffectRunner
    ) {
        self.behaviorRegistry = behaviorRegistry ?? MarkdownRuntime.makeDefaultBehaviorRegistry()
        self.stateStore = stateStore
        self.effectRunner = effectRunner
    }

    public convenience init(
        behaviorRegistry: MarkdownContract.NodeBehaviorRegistry? = nil
    ) {
        self.init(
            behaviorRegistry: behaviorRegistry,
            stateStore: MarkdownStateStore(),
            effectRunner: MarkdownEffectRunner()
        )
    }

    public func attach(to view: MarkdownContainerView) {
        if containerView !== view {
            containerView?.sceneInteractionHandler = nil
        }

        containerView = view
        view.sceneInteractionHandler = { [weak self] node, interaction in
            self?.handleSceneInteraction(node: node, interaction: interaction) ?? true
        }

        renderCurrentModel()
    }

    public func setInput(
        _ input: MarkdownRuntimeInput,
        businessContext: [String: MarkdownContract.Value] = [:]
    ) throws {
        self.businessContext = businessContext

        let model = try resolveModel(from: input)
        currentRawModel = model
        prepareState(for: model.documentId)
        renderCurrentModel()
    }

    public func setRenderModel(
        _ model: MarkdownContract.RenderModel,
        isFinal _: Bool = true,
        businessContext: [String: MarkdownContract.Value]? = nil
    ) throws {
        if let businessContext {
            self.businessContext = businessContext
        }
        currentRawModel = model
        prepareState(for: model.documentId)
        renderCurrentModel()
    }

    public func dispatch(_ event: MarkdownEvent) {
        _ = process(event: event, notifyHandler: true)
    }
}

private extension MarkdownRuntime {
    static func makeDefaultBehaviorRegistry() -> MarkdownContract.NodeBehaviorRegistry {
        MarkdownContract.NodeBehaviorRegistry(
            schemas: [
                .init(
                    kind: .link,
                    stateSlots: [:],
                    actionMappings: [:],
                    effectSpecs: [],
                    stateKeyPolicy: .auto
                ),
                .init(
                    kind: .codeBlock,
                    stateSlots: ["copyStatus": .string("idle")],
                    actionMappings: ["copyTap": "copy"],
                    effectSpecs: [
                        .init(triggerAction: "copy", emittedAction: "reset", delayMilliseconds: 5000)
                    ],
                    stateKeyPolicy: .auto
                )
            ]
        )
    }

    func resolveModel(from input: MarkdownRuntimeInput) throws -> MarkdownContract.RenderModel {
        switch input {
        case let .renderModel(model):
            return model

        case let .markdown(text, documentID, parserID, rendererID, parseOptions, rewritePipeline, renderOptions):
            guard let containerView else {
                throw MarkdownContract.ModelError(
                    code: .requiredFieldMissing,
                    message: "Attach MarkdownContainerView before markdown input",
                    path: "MarkdownRuntime.containerView"
                )
            }

            var options = parseOptions
            options.documentId = documentID

            return try containerView.contractKit.render(
                text,
                parserID: parserID,
                rendererID: rendererID,
                parseOptions: options,
                rewritePipeline: rewritePipeline,
                renderOptions: renderOptions
            )
        }
    }

    func prepareState(for documentID: String) {
        guard preparedDocumentID != documentID else { return }

        effectRunner.cancelAll()
        if let persisted = persistenceAdapter?.load(documentID: documentID) {
            var snapshot = persisted
            snapshot.documentID = documentID
            stateStore.replace(with: snapshot)
            preparedDocumentID = documentID
            return
        }

        if stateStore.snapshot.documentID != documentID {
            stateStore.reset(documentID: documentID)
        }
        preparedDocumentID = documentID
    }

    func renderCurrentModel() {
        guard let rawModel = currentRawModel else { return }
        let projected = stateProjector.project(
            model: rawModel,
            snapshot: stateStore.snapshot,
            behaviorRegistry: behaviorRegistry
        )
        containerView?.setContractRenderModel(projected)
    }

    func handleSceneInteraction(node: RenderScene.Node, interaction: SceneInteractionPayload) -> Bool {
        guard let currentRawModel else { return true }

        let eventNodeID = interaction.payload.contractString(forKey: "eventNodeID") ?? node.id
        let nodeKindRaw = interaction.payload.contractString(forKey: "eventNodeKind") ?? node.kind
        let nodeKind = MarkdownContract.NodeKind(rawValue: nodeKindRaw)
        let stateKey = MarkdownStateKeyResolver.resolve(
            nodeID: eventNodeID,
            kind: nodeKind,
            metadata: node.metadata,
            behaviorRegistry: behaviorRegistry
        )
        let resolvedStateKey = interaction.payload.contractString(forKey: "stateKey") ?? stateKey
        let action = mappedAction(for: interaction.action, kind: nodeKind)

        let context = MarkdownEventNodeContext(
            documentID: currentRawModel.documentId,
            nodeID: eventNodeID,
            nodeKind: nodeKind,
            nodeMetadata: node.metadata,
            stateKey: resolvedStateKey,
            payload: interaction.payload
        )
        let associatedData = dataBindingAdapter?.resolveAssociatedData(for: context, businessContext: businessContext) ?? [:]

        let event = MarkdownEvent(
            documentID: currentRawModel.documentId,
            nodeID: eventNodeID,
            nodeKind: nodeKind,
            stateKey: resolvedStateKey,
            action: action,
            payload: interaction.payload,
            associatedData: associatedData,
            origin: .user,
            revision: stateStore.snapshot.revision
        )

        return process(event: event, notifyHandler: true)
    }

    @discardableResult
    func process(event: MarkdownEvent, notifyHandler: Bool) -> Bool {
        guard event.documentID == stateStore.snapshot.documentID else {
            return false
        }

        if event.revision < stateStore.snapshot.revision && event.origin == .user {
            return false
        }

        let decision: MarkdownEventDecision
        if notifyHandler {
            decision = eventHandler?(event) ?? .continueDefault
        } else {
            decision = .continueDefault
        }

        let changed = reduce(event: event)
        scheduleEffects(for: event)

        if changed {
            persistenceAdapter?.save(documentID: stateStore.snapshot.documentID, snapshot: stateStore.snapshot)
            renderCurrentModel()
        }

        return decision == .continueDefault
    }

    func mappedAction(for action: String, kind: MarkdownContract.NodeKind) -> String {
        guard let schema = behaviorRegistry.schema(for: kind) else { return action }
        return schema.actionMappings[action] ?? action
    }

    func reduce(event: MarkdownEvent) -> Bool {
        var changed = false

        if let schema = behaviorRegistry.schema(for: event.nodeKind) {
            changed = stateStore.ensureDefaults(stateKey: event.stateKey, defaults: schema.stateSlots) || changed
        }

        let slotFromPayload = event.payload.contractString(forKey: "slot")
        let valueFromPayload = event.payload["value"]

        switch event.action {
        case "toggle":
            let slot = slotFromPayload ?? "collapsed"
            changed = stateStore.toggleBool(stateKey: event.stateKey, slot: slot) || changed

        case "copy":
            let slot = slotFromPayload ?? "copyStatus"
            changed = stateStore.set(stateKey: event.stateKey, slot: slot, value: .string("copied")) || changed

        case "reset":
            let slot = slotFromPayload ?? "copyStatus"
            changed = stateStore.set(stateKey: event.stateKey, slot: slot, value: .string("idle")) || changed

        case "set":
            if let slot = slotFromPayload, let value = valueFromPayload {
                changed = stateStore.set(stateKey: event.stateKey, slot: slot, value: value) || changed
            }

        default:
            if let slot = slotFromPayload, let value = valueFromPayload {
                changed = stateStore.set(stateKey: event.stateKey, slot: slot, value: value) || changed
            }
        }

        return changed
    }

    func scheduleEffects(for event: MarkdownEvent) {
        guard let schema = behaviorRegistry.schema(for: event.nodeKind) else { return }

        for effect in schema.effectSpecs where effect.triggerAction == event.action {
            let scheduledRevision = stateStore.snapshot.revision
            let effectKey = "\(event.documentID)|\(event.stateKey)|\(event.nodeID)|\(effect.emittedAction)"
            effectRunner.schedule(
                key: effectKey,
                delayMilliseconds: effect.delayMilliseconds
            ) { [weak self] in
                guard let self else { return }
                guard self.stateStore.snapshot.revision == scheduledRevision else { return }
                let emitted = MarkdownEvent(
                    documentID: event.documentID,
                    nodeID: event.nodeID,
                    nodeKind: event.nodeKind,
                    stateKey: event.stateKey,
                    action: effect.emittedAction,
                    payload: event.payload,
                    associatedData: event.associatedData,
                    origin: .effect,
                    revision: scheduledRevision
                )
                _ = self.process(event: emitted, notifyHandler: true)
            }
        }
    }
}

private struct MarkdownStateProjector {
    func project(
        model: MarkdownContract.RenderModel,
        snapshot: MarkdownStateSnapshot,
        behaviorRegistry: MarkdownContract.NodeBehaviorRegistry
    ) -> MarkdownContract.RenderModel {
        var projected = model
        projected.metadata["stateRevision"] = .int(snapshot.revision)
        projected.blocks = model.blocks.map { block in
            projectBlock(block, snapshot: snapshot, behaviorRegistry: behaviorRegistry)
        }
        return projected
    }

    func projectBlock(
        _ block: MarkdownContract.RenderBlock,
        snapshot: MarkdownStateSnapshot,
        behaviorRegistry: MarkdownContract.NodeBehaviorRegistry
    ) -> MarkdownContract.RenderBlock {
        var next = block
        let stateKey = MarkdownStateKeyResolver.resolve(
            nodeID: block.id,
            kind: block.kind,
            metadata: block.metadata,
            behaviorRegistry: behaviorRegistry
        )

        let nodeState = snapshot.nodeStates[stateKey] ?? [:]
        if !nodeState.isEmpty {
            next.metadata["uiState"] = .object(nodeState)
        }

        next.inlines = block.inlines.map { inline in
            projectInline(inline, snapshot: snapshot, behaviorRegistry: behaviorRegistry)
        }
        next.children = block.children.map { child in
            projectBlock(child, snapshot: snapshot, behaviorRegistry: behaviorRegistry)
        }

        if case let .bool(collapsed)? = nodeState["collapsed"], collapsed {
            next.children = []
        }

        return next
    }

    func projectInline(
        _ inline: MarkdownContract.InlineSpan,
        snapshot: MarkdownStateSnapshot,
        behaviorRegistry: MarkdownContract.NodeBehaviorRegistry
    ) -> MarkdownContract.InlineSpan {
        var next = inline
        let stateKey = MarkdownStateKeyResolver.resolve(
            nodeID: inline.id,
            kind: inline.kind,
            metadata: inline.metadata,
            behaviorRegistry: behaviorRegistry
        )
        if let nodeState = snapshot.nodeStates[stateKey], !nodeState.isEmpty {
            next.metadata["uiState"] = .object(nodeState)
        }
        return next
    }
}

private enum MarkdownStateKeyResolver {
    static func resolve(
        nodeID: String,
        kind: MarkdownContract.NodeKind,
        metadata: [String: MarkdownContract.Value],
        behaviorRegistry: MarkdownContract.NodeBehaviorRegistry
    ) -> String {
        let policy = behaviorRegistry.schema(for: kind)?.stateKeyPolicy ?? .auto

        switch policy {
        case .nodeID:
            return nodeID

        case .attrBusinessID:
            return businessID(from: metadata) ?? nodeID

        case .metadataStateKey:
            return metadataString(from: metadata, key: "stateKey") ?? nodeID

        case .auto:
            return businessID(from: metadata)
                ?? metadataString(from: metadata, key: "stateKey")
                ?? nodeID
        }
    }

    static func businessID(from metadata: [String: MarkdownContract.Value]) -> String? {
        metadataString(from: metadata, key: "businessID")
            ?? metadataString(from: metadata, key: "businessId")
            ?? metadataString(from: metadata, key: "id")
    }

    static func metadataString(
        from metadata: [String: MarkdownContract.Value],
        key: String
    ) -> String? {
        if case let .string(value)? = metadata[key] {
            return value
        }

        guard case let .object(attrs)? = metadata["attrs"] else {
            return nil
        }

        if case let .string(value)? = attrs[key] {
            return value
        }

        if case let .object(htmlAttrs)? = attrs["attributes"], case let .string(value)? = htmlAttrs[key] {
            return value
        }

        return nil
    }
}

private extension Dictionary where Key == String, Value == MarkdownContract.Value {
    func contractString(forKey key: String) -> String? {
        guard case let .string(value)? = self[key] else {
            return nil
        }
        return value
    }
}
