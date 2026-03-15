import Foundation

extension MarkdownContract {
    public enum NodeRole: String, Sendable, Equatable, Hashable, Codable {
        case root
        case blockLeaf
        case blockContainer
        case inlineLeaf
        case inlineContainer

        public var isBlock: Bool {
            self == .blockLeaf || self == .blockContainer || self == .root
        }

        public var isInline: Bool {
            self == .inlineLeaf || self == .inlineContainer
        }
    }

    public struct ChildPolicy: Sendable, Equatable {
        public var allowedChildRoles: Set<NodeRole>
        public var minChildren: Int
        public var maxChildren: Int?

        public init(
            allowedChildRoles: Set<NodeRole>,
            minChildren: Int = 0,
            maxChildren: Int? = nil
        ) {
            self.allowedChildRoles = allowedChildRoles
            self.minChildren = minChildren
            self.maxChildren = maxChildren
        }

        public static let none = ChildPolicy(allowedChildRoles: [], minChildren: 0, maxChildren: 0)

        public static func blockOnly(minChildren: Int = 0, maxChildren: Int? = nil) -> ChildPolicy {
            ChildPolicy(
                allowedChildRoles: [.blockLeaf, .blockContainer],
                minChildren: minChildren,
                maxChildren: maxChildren
            )
        }

        public static func inlineOnly(minChildren: Int = 0, maxChildren: Int? = nil) -> ChildPolicy {
            ChildPolicy(
                allowedChildRoles: [.inlineLeaf, .inlineContainer],
                minChildren: minChildren,
                maxChildren: maxChildren
            )
        }

        public static func mixed(minChildren: Int = 0, maxChildren: Int? = nil) -> ChildPolicy {
            ChildPolicy(
                allowedChildRoles: [.blockLeaf, .blockContainer, .inlineLeaf, .inlineContainer],
                minChildren: minChildren,
                maxChildren: maxChildren
            )
        }
    }

    public struct ParseAlias: Sendable, Equatable, Hashable {
        public var sourceKind: SourceKind
        public var name: String

        public init(sourceKind: SourceKind, name: String) {
            self.sourceKind = sourceKind
            self.name = name.lowercased()
        }
    }

    public struct NodeSpec: Sendable, Equatable {
        public var kind: NodeKind
        public var role: NodeRole
        public var childPolicy: ChildPolicy
        public var parseAliases: [ParseAlias]

        public init(
            kind: NodeKind,
            role: NodeRole,
            childPolicy: ChildPolicy,
            parseAliases: [ParseAlias] = []
        ) {
            self.kind = kind
            self.role = role
            self.childPolicy = childPolicy
            self.parseAliases = parseAliases
        }

        public static func core(
            _ kind: CoreNodeKind,
            role: NodeRole,
            childPolicy: ChildPolicy,
            parseAliases: [ParseAlias] = []
        ) -> NodeSpec {
            NodeSpec(kind: .core(kind), role: role, childPolicy: childPolicy, parseAliases: parseAliases)
        }
    }

    public final class NodeSpecRegistry: @unchecked Sendable {
        private var specsByKind: [NodeKind: NodeSpec]
        private var kindByAlias: [ParseAlias: NodeKind]

        public init(registerCoreSpecs: Bool = true) {
            self.specsByKind = [:]
            self.kindByAlias = [:]

            if registerCoreSpecs {
                for spec in Self.coreSpecs {
                    register(spec)
                }
            }
        }

        public func register(_ spec: NodeSpec) {
            specsByKind[spec.kind] = spec
            for alias in spec.parseAliases {
                kindByAlias[alias] = spec.kind
            }
        }

        public func spec(for kind: NodeKind) -> NodeSpec? {
            specsByKind[kind]
        }

        public func resolveKind(sourceKind: SourceKind, name: String) -> NodeKind? {
            let key = ParseAlias(sourceKind: sourceKind, name: name)
            return kindByAlias[key]
        }

        public static func core() -> NodeSpecRegistry {
            NodeSpecRegistry(registerCoreSpecs: true)
        }

        public static let coreSpecs: [NodeSpec] = [
            .core(.document, role: .root, childPolicy: .blockOnly()),
            .core(.paragraph, role: .blockContainer, childPolicy: .inlineOnly()),
            .core(.heading, role: .blockContainer, childPolicy: .inlineOnly()),
            .core(.list, role: .blockContainer, childPolicy: .blockOnly(minChildren: 1)),
            .core(.listItem, role: .blockContainer, childPolicy: .blockOnly(minChildren: 0)),
            .core(.blockQuote, role: .blockContainer, childPolicy: .blockOnly(minChildren: 0)),
            .core(.codeBlock, role: .blockLeaf, childPolicy: .none),
            .core(.table, role: .blockContainer, childPolicy: .mixed(minChildren: 0)),
            .core(.tableHead, role: .blockContainer, childPolicy: .mixed(minChildren: 0)),
            .core(.tableBody, role: .blockContainer, childPolicy: .mixed(minChildren: 0)),
            .core(.tableRow, role: .blockContainer, childPolicy: .mixed(minChildren: 0)),
            .core(.tableCell, role: .blockContainer, childPolicy: .mixed(minChildren: 0)),
            .core(.thematicBreak, role: .blockLeaf, childPolicy: .none),
            .core(.image, role: .inlineLeaf, childPolicy: .none),
            .core(.text, role: .inlineLeaf, childPolicy: .none),
            .core(.link, role: .inlineContainer, childPolicy: .inlineOnly(minChildren: 0)),
            .core(.emphasis, role: .inlineContainer, childPolicy: .inlineOnly(minChildren: 0)),
            .core(.strong, role: .inlineContainer, childPolicy: .inlineOnly(minChildren: 0)),
            .core(.strikethrough, role: .inlineContainer, childPolicy: .inlineOnly(minChildren: 0)),
            .core(.inlineCode, role: .inlineLeaf, childPolicy: .none),
            .core(.softBreak, role: .inlineLeaf, childPolicy: .none),
            .core(.hardBreak, role: .inlineLeaf, childPolicy: .none),
            .core(.custom, role: .blockContainer, childPolicy: .mixed(minChildren: 0))
        ]
    }

    public struct TreeValidator: Sendable {
        public var registry: NodeSpecRegistry

        public init(registry: NodeSpecRegistry) {
            self.registry = registry
        }

        public func validate(document: CanonicalDocument) throws {
            try validate(node: document.root, path: "root")
        }

        private func validate(node: CanonicalNode, path: String) throws {
            guard let spec = registry.spec(for: node.kind) else {
                throw MarkdownContract.ModelError(
                    code: .unknownNodeKind,
                    message: "Node kind is not registered: \(node.kind.rawValue)",
                    path: "\(path).kind"
                )
            }

            let count = node.children.count
            if count < spec.childPolicy.minChildren {
                throw MarkdownContract.ModelError(
                    code: .schemaInvalid,
                    message: "Node has fewer children than allowed: \(spec.childPolicy.minChildren)",
                    path: "\(path).children"
                )
            }

            if let max = spec.childPolicy.maxChildren, count > max {
                throw MarkdownContract.ModelError(
                    code: .schemaInvalid,
                    message: "Node has more children than allowed: \(max)",
                    path: "\(path).children"
                )
            }

            for (index, child) in node.children.enumerated() {
                guard let childSpec = registry.spec(for: child.kind) else {
                    throw MarkdownContract.ModelError(
                        code: .unknownNodeKind,
                        message: "Node kind is not registered: \(child.kind.rawValue)",
                        path: "\(path).children[\(index)].kind"
                    )
                }

                if !spec.childPolicy.allowedChildRoles.contains(childSpec.role) {
                    throw MarkdownContract.ModelError(
                        code: .schemaInvalid,
                        message: "Child role \(childSpec.role.rawValue) is not allowed under \(spec.role.rawValue)",
                        path: "\(path).children[\(index)]"
                    )
                }

                try validate(node: child, path: "\(path).children[\(index)]")
            }
        }
    }
}
