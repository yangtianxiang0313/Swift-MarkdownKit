import Foundation

extension MarkdownContract {
    public enum TagPairingMode: String, Sendable, Equatable, Codable {
        case selfClosing
        case paired
        case both

        public var supportsSelfClosing: Bool {
            self == .selfClosing || self == .both
        }

        public var supportsPaired: Bool {
            self == .paired || self == .both
        }
    }

    public struct TagSchema: Sendable, Equatable, Codable {
        public var tagName: String
        public var nodeKind: NodeKind
        public var role: NodeRole
        public var childPolicy: ChildPolicy
        public var pairingMode: TagPairingMode

        public init(
            tagName: String,
            nodeKind: NodeKind,
            role: NodeRole,
            childPolicy: ChildPolicy,
            pairingMode: TagPairingMode
        ) {
            self.tagName = tagName.lowercased()
            self.nodeKind = nodeKind
            self.role = role
            self.childPolicy = childPolicy
            self.pairingMode = pairingMode
        }

        public func makeNodeSpec() -> NodeSpec {
            NodeSpec(
                kind: nodeKind,
                role: role,
                childPolicy: childPolicy,
                parseAliases: [.init(sourceKind: .htmlTag, name: tagName)]
            )
        }
    }

    public final class TagSchemaRegistry: @unchecked Sendable {
        private var schemasByTagName: [String: TagSchema]

        public init(schemas: [TagSchema] = []) {
            self.schemasByTagName = [:]
            schemas.forEach { register($0) }
        }

        public func register(_ schema: TagSchema) {
            schemasByTagName[schema.tagName] = schema
        }

        public func schema(forHTMLTag tagName: String) -> TagSchema? {
            schemasByTagName[tagName.lowercased()]
        }

        public func allSchemas() -> [TagSchema] {
            Array(schemasByTagName.values)
        }

        public func install(into nodeSpecRegistry: NodeSpecRegistry) {
            for schema in schemasByTagName.values {
                nodeSpecRegistry.registerTagSchema(schema)
            }
        }
    }
}
