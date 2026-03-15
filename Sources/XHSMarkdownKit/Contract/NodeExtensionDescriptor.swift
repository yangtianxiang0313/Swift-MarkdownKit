import Foundation

extension MarkdownContract {
    public enum NodeChildPolicySpec: Sendable, Equatable {
        case none
        case blockOnly(minChildren: Int = 0, maxChildren: Int? = nil)
        case inlineOnly(minChildren: Int = 0, maxChildren: Int? = nil)
        case mixed(minChildren: Int = 0, maxChildren: Int? = nil)
        case custom(allowedChildRoles: Set<NodeRole>, minChildren: Int = 0, maxChildren: Int? = nil)

        public init(childPolicy: ChildPolicy) {
            let roles = childPolicy.allowedChildRoles
            let minChildren = childPolicy.minChildren
            let maxChildren = childPolicy.maxChildren
            if roles.isEmpty && maxChildren == 0 {
                self = .none
                return
            }
            if roles == [.blockLeaf, .blockContainer] {
                self = .blockOnly(minChildren: minChildren, maxChildren: maxChildren)
                return
            }
            if roles == [.inlineLeaf, .inlineContainer] {
                self = .inlineOnly(minChildren: minChildren, maxChildren: maxChildren)
                return
            }
            if roles == [.blockLeaf, .blockContainer, .inlineLeaf, .inlineContainer] {
                self = .mixed(minChildren: minChildren, maxChildren: maxChildren)
                return
            }
            self = .custom(allowedChildRoles: roles, minChildren: minChildren, maxChildren: maxChildren)
        }

        public func makeChildPolicy() -> ChildPolicy {
            switch self {
            case .none:
                return .none
            case let .blockOnly(minChildren, maxChildren):
                return .blockOnly(minChildren: minChildren, maxChildren: maxChildren)
            case let .inlineOnly(minChildren, maxChildren):
                return .inlineOnly(minChildren: minChildren, maxChildren: maxChildren)
            case let .mixed(minChildren, maxChildren):
                return .mixed(minChildren: minChildren, maxChildren: maxChildren)
            case let .custom(allowedChildRoles, minChildren, maxChildren):
                return ChildPolicy(
                    allowedChildRoles: allowedChildRoles,
                    minChildren: minChildren,
                    maxChildren: maxChildren
                )
            }
        }
    }
}

extension MarkdownContract.NodeChildPolicySpec: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case minChildren
        case maxChildren
        case allowedChildRoles
    }

    private enum Kind: String, Codable {
        case none
        case blockOnly
        case inlineOnly
        case mixed
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        let minChildren = max(0, try container.decodeIfPresent(Int.self, forKey: .minChildren) ?? 0)
        let maxChildren = try container.decodeIfPresent(Int.self, forKey: .maxChildren)

        switch kind {
        case .none:
            self = .none
        case .blockOnly:
            self = .blockOnly(minChildren: minChildren, maxChildren: maxChildren)
        case .inlineOnly:
            self = .inlineOnly(minChildren: minChildren, maxChildren: maxChildren)
        case .mixed:
            self = .mixed(minChildren: minChildren, maxChildren: maxChildren)
        case .custom:
            let roles = Set(try container.decodeIfPresent([MarkdownContract.NodeRole].self, forKey: .allowedChildRoles) ?? [])
            self = .custom(
                allowedChildRoles: roles,
                minChildren: minChildren,
                maxChildren: maxChildren
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .type)
            try container.encode(0, forKey: .minChildren)
            try container.encode(0, forKey: .maxChildren)

        case let .blockOnly(minChildren, maxChildren):
            try container.encode(Kind.blockOnly, forKey: .type)
            try container.encode(minChildren, forKey: .minChildren)
            try container.encodeIfPresent(maxChildren, forKey: .maxChildren)

        case let .inlineOnly(minChildren, maxChildren):
            try container.encode(Kind.inlineOnly, forKey: .type)
            try container.encode(minChildren, forKey: .minChildren)
            try container.encodeIfPresent(maxChildren, forKey: .maxChildren)

        case let .mixed(minChildren, maxChildren):
            try container.encode(Kind.mixed, forKey: .type)
            try container.encode(minChildren, forKey: .minChildren)
            try container.encodeIfPresent(maxChildren, forKey: .maxChildren)

        case let .custom(allowedChildRoles, minChildren, maxChildren):
            try container.encode(Kind.custom, forKey: .type)
            try container.encode(minChildren, forKey: .minChildren)
            try container.encodeIfPresent(maxChildren, forKey: .maxChildren)
            try container.encode(Array(allowedChildRoles), forKey: .allowedChildRoles)
        }
    }
}

extension MarkdownContract {
    public struct ExtensionTagSchema: Sendable, Equatable, Codable {
        public var tagName: String
        public var nodeKind: NodeKind
        public var role: NodeRole
        public var childPolicy: NodeChildPolicySpec
        public var pairingMode: TagPairingMode

        public init(
            tagName: String,
            nodeKind: NodeKind,
            role: NodeRole,
            childPolicy: NodeChildPolicySpec,
            pairingMode: TagPairingMode
        ) {
            self.tagName = tagName
            self.nodeKind = nodeKind
            self.role = role
            self.childPolicy = childPolicy
            self.pairingMode = pairingMode
        }

        public init(tagSchema: TagSchema) {
            self.tagName = tagSchema.tagName
            self.nodeKind = tagSchema.nodeKind
            self.role = tagSchema.role
            self.childPolicy = .init(childPolicy: tagSchema.childPolicy)
            self.pairingMode = tagSchema.pairingMode
        }

        public func makeTagSchema() -> TagSchema {
            TagSchema(
                tagName: tagName,
                nodeKind: nodeKind,
                role: role,
                childPolicy: childPolicy.makeChildPolicy(),
                pairingMode: pairingMode
            )
        }
    }

    public struct NodeExtensionDescriptor: Sendable, Equatable, Codable {
        public var id: String
        public var tag: ExtensionTagSchema?
        public var behavior: NodeBehaviorSchema?
        public var metadata: [String: Value]

        private enum CodingKeys: String, CodingKey {
            case id
            case tag
            case behavior
            case metadata
        }

        public init(
            id: String,
            tag: ExtensionTagSchema? = nil,
            behavior: NodeBehaviorSchema? = nil,
            metadata: [String: Value] = [:]
        ) {
            self.id = id
            self.tag = tag
            self.behavior = behavior
            self.metadata = metadata
        }

        public init(
            id: String,
            tagSchema: TagSchema? = nil,
            behavior: NodeBehaviorSchema? = nil,
            metadata: [String: Value] = [:]
        ) {
            self.id = id
            self.tag = tagSchema.map(ExtensionTagSchema.init(tagSchema:))
            self.behavior = behavior
            self.metadata = metadata
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            tag = try container.decodeIfPresent(ExtensionTagSchema.self, forKey: .tag)
            behavior = try container.decodeIfPresent(NodeBehaviorSchema.self, forKey: .behavior)
            metadata = try container.decodeIfPresent([String: Value].self, forKey: .metadata) ?? [:]
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(tag, forKey: .tag)
            try container.encodeIfPresent(behavior, forKey: .behavior)
            if !metadata.isEmpty {
                try container.encode(metadata, forKey: .metadata)
            }
        }

        public var nodeKind: NodeKind? {
            tag?.nodeKind ?? behavior?.kind
        }

        public func makeTagSchema() -> TagSchema? {
            tag?.makeTagSchema()
        }

        public func validate() throws {
            let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else {
                throw ModelError(
                    code: .requiredFieldMissing,
                    message: "NodeExtensionDescriptor.id is required",
                    path: "id"
                )
            }
            guard tag != nil || behavior != nil else {
                throw ModelError(
                    code: .requiredFieldMissing,
                    message: "NodeExtensionDescriptor requires at least one of tag or behavior",
                    path: "tag"
                )
            }
            if let tag, tag.tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ModelError(
                    code: .requiredFieldMissing,
                    message: "NodeExtensionDescriptor.tag.tagName is required",
                    path: "tag.tagName"
                )
            }
            if let tag, let behavior, tag.nodeKind != behavior.kind {
                throw ModelError(
                    code: .schemaInvalid,
                    message: "tag.nodeKind and behavior.kind must be the same",
                    path: "behavior.kind",
                    details: [
                        "tagNodeKind": .string(tag.nodeKind.rawValue),
                        "behaviorKind": .string(behavior.kind.rawValue)
                    ]
                )
            }
        }
    }

    public final class NodeExtensionRegistry: @unchecked Sendable {
        private var descriptorsByID: [String: NodeExtensionDescriptor]

        public init(descriptors: [NodeExtensionDescriptor] = []) throws {
            self.descriptorsByID = [:]
            for descriptor in descriptors {
                try register(descriptor)
            }
        }

        public func register(_ descriptor: NodeExtensionDescriptor) throws {
            try descriptor.validate()
            descriptorsByID[descriptor.id] = descriptor
        }

        public func descriptor(forID id: String) -> NodeExtensionDescriptor? {
            descriptorsByID[id]
        }

        public func allDescriptors() -> [NodeExtensionDescriptor] {
            descriptorsByID.values.sorted { lhs, rhs in
                lhs.id < rhs.id
            }
        }

        public func installStructure(into nodeSpecRegistry: NodeSpecRegistry) {
            for descriptor in allDescriptors() {
                if let tagSchema = descriptor.makeTagSchema() {
                    nodeSpecRegistry.registerTagSchema(tagSchema)
                }
            }
        }

        public func installBehavior(into behaviorRegistry: NodeBehaviorRegistry) {
            for descriptor in allDescriptors() {
                if let behavior = descriptor.behavior {
                    behaviorRegistry.register(behavior)
                }
            }
        }

        public func makeTagSchemaRegistry() -> TagSchemaRegistry {
            let schemas = allDescriptors().compactMap { $0.makeTagSchema() }
            return TagSchemaRegistry(schemas: schemas)
        }

        public func makeBehaviorRegistry() -> NodeBehaviorRegistry {
            let schemas = allDescriptors().compactMap(\.behavior)
            return NodeBehaviorRegistry(schemas: schemas)
        }
    }
}

public extension MarkdownContract.NodeSpecRegistry {
    func registerExtensionDescriptors(_ descriptors: [MarkdownContract.NodeExtensionDescriptor]) throws {
        for descriptor in descriptors {
            try descriptor.validate()
            if let tagSchema = descriptor.makeTagSchema() {
                registerTagSchema(tagSchema)
            }
        }
    }
}

public extension MarkdownContract.TagSchemaRegistry {
    convenience init(extensionDescriptors: [MarkdownContract.NodeExtensionDescriptor]) throws {
        let schemas = try extensionDescriptors.compactMap { descriptor -> MarkdownContract.TagSchema? in
            try descriptor.validate()
            return descriptor.makeTagSchema()
        }
        self.init(schemas: schemas)
    }
}

public extension MarkdownContract.NodeBehaviorRegistry {
    convenience init(extensionDescriptors: [MarkdownContract.NodeExtensionDescriptor]) throws {
        let schemas = try extensionDescriptors.compactMap { descriptor -> MarkdownContract.NodeBehaviorSchema? in
            try descriptor.validate()
            return descriptor.behavior
        }
        self.init(schemas: schemas)
    }
}
