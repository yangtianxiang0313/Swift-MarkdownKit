import Foundation

extension MarkdownContract {
    public enum StateKeyPolicy: String, Sendable, Equatable, Codable {
        case auto
        case nodeID
        case attrBusinessID
        case metadataStateKey
    }

    public struct BehaviorEffectSpec: Sendable, Equatable, Codable {
        public var triggerAction: String
        public var emittedAction: String
        public var delayMilliseconds: Int

        public init(
            triggerAction: String,
            emittedAction: String,
            delayMilliseconds: Int
        ) {
            self.triggerAction = triggerAction
            self.emittedAction = emittedAction
            self.delayMilliseconds = max(0, delayMilliseconds)
        }
    }

    public struct NodeBehaviorSchema: Sendable, Equatable, Codable {
        public var kind: NodeKind
        public var stateSlots: [String: Value]
        public var actionMappings: [String: String]
        public var effectSpecs: [BehaviorEffectSpec]
        public var stateKeyPolicy: StateKeyPolicy

        private enum CodingKeys: String, CodingKey {
            case kind
            case stateSlots
            case actionMappings
            case effectSpecs
            case stateKeyPolicy
        }

        public init(
            kind: NodeKind,
            stateSlots: [String: Value] = [:],
            actionMappings: [String: String] = [:],
            effectSpecs: [BehaviorEffectSpec] = [],
            stateKeyPolicy: StateKeyPolicy = .auto
        ) {
            self.kind = kind
            self.stateSlots = stateSlots
            self.actionMappings = actionMappings
            self.effectSpecs = effectSpecs
            self.stateKeyPolicy = stateKeyPolicy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = try container.decode(NodeKind.self, forKey: .kind)

            let decodedSlots = try container.decodeIfPresent([String: LenientValue].self, forKey: .stateSlots) ?? [:]
            stateSlots = decodedSlots.mapValues(\.value)
            actionMappings = try container.decodeIfPresent([String: String].self, forKey: .actionMappings) ?? [:]
            effectSpecs = try container.decodeIfPresent([BehaviorEffectSpec].self, forKey: .effectSpecs) ?? []
            stateKeyPolicy = try container.decodeIfPresent(StateKeyPolicy.self, forKey: .stateKeyPolicy) ?? .auto
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: .kind)
            if !stateSlots.isEmpty {
                try container.encode(stateSlots, forKey: .stateSlots)
            }
            if !actionMappings.isEmpty {
                try container.encode(actionMappings, forKey: .actionMappings)
            }
            if !effectSpecs.isEmpty {
                try container.encode(effectSpecs, forKey: .effectSpecs)
            }
            try container.encode(stateKeyPolicy, forKey: .stateKeyPolicy)
        }
    }

    public final class NodeBehaviorRegistry: @unchecked Sendable {
        private var schemasByKind: [NodeKind: NodeBehaviorSchema]

        public init(schemas: [NodeBehaviorSchema] = []) {
            self.schemasByKind = [:]
            schemas.forEach { register($0) }
        }

        public func register(_ schema: NodeBehaviorSchema) {
            schemasByKind[schema.kind] = schema
        }

        public func schema(for kind: NodeKind) -> NodeBehaviorSchema? {
            schemasByKind[kind]
        }

        public func allSchemas() -> [NodeBehaviorSchema] {
            Array(schemasByKind.values)
        }
    }
}

private struct LenientValue: Decodable {
    let value: MarkdownContract.Value

    init(from decoder: Decoder) throws {
        if let wrapped = try? MarkdownContract.Value(from: decoder) {
            value = wrapped
            return
        }

        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            value = .null
            return
        }
        if let bool = try? single.decode(Bool.self) {
            value = .bool(bool)
            return
        }
        if let int = try? single.decode(Int.self) {
            value = .int(int)
            return
        }
        if let double = try? single.decode(Double.self) {
            value = .double(double)
            return
        }
        if let string = try? single.decode(String.self) {
            value = .string(string)
            return
        }
        if let array = try? single.decode([LenientValue].self) {
            value = .array(array.map(\.value))
            return
        }
        if let object = try? single.decode([String: LenientValue].self) {
            value = .object(object.mapValues(\.value))
            return
        }

        throw DecodingError.typeMismatch(
            MarkdownContract.Value.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
        )
    }
}
