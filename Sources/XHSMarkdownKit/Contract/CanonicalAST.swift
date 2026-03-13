import Foundation

extension MarkdownContract {
    public enum SourceKind: Sendable, Equatable {
        case markdown
        case directive
        case htmlTag
        case custom(String)
    }

    public enum NodeKind: Sendable, Equatable {
        case document
        case paragraph
        case heading
        case list
        case listItem
        case blockQuote
        case codeBlock
        case table
        case thematicBreak
        case image
        case text
        case link
        case emphasis
        case strong
        case inlineCode
        case customElement
        case custom(String)
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

        switch self {
        case .markdown: try container.encode("markdown")
        case .directive: try container.encode("directive")
        case .htmlTag: try container.encode("htmlTag")
        case .custom(let raw): try container.encode(raw)
        }
    }
}

// MARK: - NodeKind Codable

extension MarkdownContract.NodeKind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw {
        case "document": self = .document
        case "paragraph": self = .paragraph
        case "heading": self = .heading
        case "list": self = .list
        case "listItem": self = .listItem
        case "blockQuote": self = .blockQuote
        case "codeBlock": self = .codeBlock
        case "table": self = .table
        case "thematicBreak": self = .thematicBreak
        case "image": self = .image
        case "text": self = .text
        case "link": self = .link
        case "emphasis": self = .emphasis
        case "strong": self = .strong
        case "inlineCode": self = .inlineCode
        case "customElement": self = .customElement
        default:
            self = .custom(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .document: try container.encode("document")
        case .paragraph: try container.encode("paragraph")
        case .heading: try container.encode("heading")
        case .list: try container.encode("list")
        case .listItem: try container.encode("listItem")
        case .blockQuote: try container.encode("blockQuote")
        case .codeBlock: try container.encode("codeBlock")
        case .table: try container.encode("table")
        case .thematicBreak: try container.encode("thematicBreak")
        case .image: try container.encode("image")
        case .text: try container.encode("text")
        case .link: try container.encode("link")
        case .emphasis: try container.encode("emphasis")
        case .strong: try container.encode("strong")
        case .inlineCode: try container.encode("inlineCode")
        case .customElement: try container.encode("customElement")
        case .custom(let raw): try container.encode(raw)
        }
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
