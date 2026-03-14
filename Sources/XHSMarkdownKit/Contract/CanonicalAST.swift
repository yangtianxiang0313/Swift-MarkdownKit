import Foundation

extension MarkdownContract {
    public enum SourceKind: Sendable, Equatable, Hashable {
        case markdown
        case directive
        case htmlTag
        case custom(String)

        public var key: String {
            switch self {
            case .markdown: return "markdown"
            case .directive: return "directive"
            case .htmlTag: return "htmlTag"
            case .custom(let raw): return raw
            }
        }
    }

    public struct ExtensionNodeKind: Sendable, Equatable, Hashable, Codable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(namespace: String, name: String) {
            self.rawValue = "ext.\(namespace).\(name)"
        }
    }

    public enum CoreNodeKind: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
        case document
        case paragraph
        case heading
        case list
        case listItem
        case blockQuote
        case codeBlock
        case table
        case tableHead
        case tableBody
        case tableRow
        case tableCell
        case thematicBreak
        case image
        case text
        case link
        case emphasis
        case strong
        case inlineCode
        case softBreak
        case hardBreak
        case custom
    }

    public enum NodeKind: Sendable, Equatable, Hashable {
        case core(CoreNodeKind)
        case ext(ExtensionNodeKind)

        public var rawValue: String {
            switch self {
            case .core(let kind): return kind.rawValue
            case .ext(let kind): return kind.rawValue
            }
        }

        public var coreKind: CoreNodeKind? {
            guard case let .core(kind) = self else { return nil }
            return kind
        }

        public var isExtension: Bool {
            if case .ext = self { return true }
            return false
        }

        public init(rawValue: String) {
            if let core = CoreNodeKind(rawValue: rawValue) {
                self = .core(core)
            } else {
                self = .ext(.init(rawValue: rawValue))
            }
        }

        public static var document: NodeKind { .core(.document) }
        public static var paragraph: NodeKind { .core(.paragraph) }
        public static var heading: NodeKind { .core(.heading) }
        public static var list: NodeKind { .core(.list) }
        public static var listItem: NodeKind { .core(.listItem) }
        public static var blockQuote: NodeKind { .core(.blockQuote) }
        public static var codeBlock: NodeKind { .core(.codeBlock) }
        public static var table: NodeKind { .core(.table) }
        public static var tableHead: NodeKind { .core(.tableHead) }
        public static var tableBody: NodeKind { .core(.tableBody) }
        public static var tableRow: NodeKind { .core(.tableRow) }
        public static var tableCell: NodeKind { .core(.tableCell) }
        public static var thematicBreak: NodeKind { .core(.thematicBreak) }
        public static var image: NodeKind { .core(.image) }
        public static var text: NodeKind { .core(.text) }
        public static var link: NodeKind { .core(.link) }
        public static var emphasis: NodeKind { .core(.emphasis) }
        public static var strong: NodeKind { .core(.strong) }
        public static var inlineCode: NodeKind { .core(.inlineCode) }
        public static var softBreak: NodeKind { .core(.softBreak) }
        public static var hardBreak: NodeKind { .core(.hardBreak) }
        public static var custom: NodeKind { .core(.custom) }
    }

    public struct SourcePosition: Sendable, Equatable, Codable {
        public var startLine: Int
        public var startColumn: Int
        public var endLine: Int
        public var endColumn: Int

        public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
            self.startLine = startLine
            self.startColumn = startColumn
            self.endLine = endLine
            self.endColumn = endColumn
        }
    }

    public struct SourceInfo: Sendable, Equatable, Codable {
        public var sourceKind: SourceKind
        public var raw: String?
        public var position: SourcePosition?
        public var additionalFields: [String: Value]

        public init(
            sourceKind: SourceKind,
            raw: String? = nil,
            position: SourcePosition? = nil,
            additionalFields: [String: Value] = [:]
        ) {
            self.sourceKind = sourceKind
            self.raw = raw
            self.position = position
            self.additionalFields = additionalFields
        }
    }

    public struct CanonicalNode: Sendable, Equatable, Codable {
        public var id: String
        public var kind: NodeKind
        public var attrs: [String: Value]
        public var children: [CanonicalNode]
        public var source: SourceInfo
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            id: String,
            kind: NodeKind,
            attrs: [String: Value] = [:],
            children: [CanonicalNode] = [],
            source: SourceInfo,
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.attrs = attrs
            self.children = children
            self.source = source
            self.metadata = metadata
            self.additionalFields = additionalFields
        }
    }

    public struct CanonicalDocument: Sendable, Equatable, Codable {
        public var schemaVersion: Int
        public var documentId: String
        public var root: CanonicalNode
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            schemaVersion: Int = MarkdownContract.schemaVersion,
            documentId: String,
            root: CanonicalNode,
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.schemaVersion = schemaVersion
            self.documentId = documentId
            self.root = root
            self.metadata = metadata
            self.additionalFields = additionalFields
        }

        public func validate() throws {
            guard schemaVersion == MarkdownContract.schemaVersion else {
                throw MarkdownContract.ModelError(code: .unsupportedVersion, message: "Unsupported schemaVersion: \(schemaVersion)", path: "schemaVersion")
            }

            if root.kind != .document {
                throw MarkdownContract.ModelError(code: .schemaInvalid, message: "Root node kind must be document", path: "root.kind")
            }
        }
    }
}

// MARK: - SourceKind Codable

extension MarkdownContract.SourceKind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw {
        case "markdown": self = .markdown
        case "directive": self = .directive
        case "htmlTag": self = .htmlTag
        default: self = .custom(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
}

// MARK: - NodeKind Codable

extension MarkdownContract.NodeKind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = MarkdownContract.NodeKind(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - SourceInfo Codable (unknown field preserving)

extension MarkdownContract.SourceInfo {
    private enum CodingKeys: String, CodingKey {
        case sourceKind
        case raw
        case position
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceKind = try container.decode(MarkdownContract.SourceKind.self, forKey: .sourceKind)
        raw = try container.decodeIfPresent(String.self, forKey: .raw)
        position = try container.decodeIfPresent(MarkdownContract.SourcePosition.self, forKey: .position)
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.sourceKind.rawValue,
            CodingKeys.raw.rawValue,
            CodingKeys.position.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceKind, forKey: .sourceKind)
        try container.encodeIfPresent(raw, forKey: .raw)
        try container.encodeIfPresent(position, forKey: .position)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.sourceKind.rawValue,
            CodingKeys.raw.rawValue,
            CodingKeys.position.rawValue
        ])
    }
}

// MARK: - CanonicalNode Codable (unknown field preserving)

extension MarkdownContract.CanonicalNode {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case attrs
        case children
        case source
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MarkdownContract.NodeKind.self, forKey: .kind)
        attrs = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .attrs) ?? [:]
        children = try container.decodeIfPresent([MarkdownContract.CanonicalNode].self, forKey: .children) ?? []
        source = try container.decode(MarkdownContract.SourceInfo.self, forKey: .source)
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]

        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.id.rawValue,
            CodingKeys.kind.rawValue,
            CodingKeys.attrs.rawValue,
            CodingKeys.children.rawValue,
            CodingKeys.source.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(attrs, forKey: .attrs)
        try container.encode(children, forKey: .children)
        try container.encode(source, forKey: .source)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.id.rawValue,
            CodingKeys.kind.rawValue,
            CodingKeys.attrs.rawValue,
            CodingKeys.children.rawValue,
            CodingKeys.source.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}

// MARK: - CanonicalDocument Codable (unknown field preserving)

extension MarkdownContract.CanonicalDocument {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case documentId
        case root
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        documentId = try container.decode(String.self, forKey: .documentId)
        root = try container.decode(MarkdownContract.CanonicalNode.self, forKey: .root)
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.documentId.rawValue,
            CodingKeys.root.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(root, forKey: .root)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.documentId.rawValue,
            CodingKeys.root.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}
