import Foundation

extension MarkdownContract {
    public enum BlockKind: Sendable, Equatable {
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
        case custom
        case customRaw(String)
    }

    public enum InlineKind: Sendable, Equatable {
        case text
        case code
        case link
        case image
        case softBreak
        case hardBreak
        case custom
        case customRaw(String)
    }

    public struct StyleToken: Sendable, Equatable, Codable {
        public var name: String
        public var value: StyleValue

        public init(name: String, value: StyleValue) {
            self.name = name
            self.value = value
        }
    }

    public struct MarkToken: Sendable, Equatable, Codable {
        public var name: String
        public var value: Value?

        public init(name: String, value: Value? = nil) {
            self.name = name
            self.value = value
        }
    }

    public struct LayoutHints: Sendable, Equatable, Codable {
        public var spacingBefore: Double?
        public var spacingAfter: Double?
        public var indent: Double?
        public var maxWidth: Double?

        public init(
            spacingBefore: Double? = nil,
            spacingAfter: Double? = nil,
            indent: Double? = nil,
            maxWidth: Double? = nil
        ) {
            self.spacingBefore = spacingBefore
            self.spacingAfter = spacingAfter
            self.indent = indent
            self.maxWidth = maxWidth
        }
    }

    public struct InlineSpan: Sendable, Equatable, Codable {
        public var id: String
        public var kind: InlineKind
        public var text: String
        public var marks: [MarkToken]
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            id: String,
            kind: InlineKind,
            text: String = "",
            marks: [MarkToken] = [],
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.text = text
            self.marks = marks
            self.metadata = metadata
            self.additionalFields = additionalFields
        }
    }

    public struct RenderAsset: Sendable, Equatable, Codable {
        public var id: String
        public var type: String
        public var source: String
        public var metadata: [String: Value]

        public init(id: String, type: String, source: String, metadata: [String: Value] = [:]) {
            self.id = id
            self.type = type
            self.source = source
            self.metadata = metadata
        }
    }

    public struct RenderBlock: Sendable, Equatable, Codable {
        public var id: String
        public var kind: BlockKind
        public var inlines: [InlineSpan]
        public var children: [RenderBlock]
        public var styleTokens: [StyleToken]
        public var layoutHints: LayoutHints
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            id: String,
            kind: BlockKind,
            inlines: [InlineSpan] = [],
            children: [RenderBlock] = [],
            styleTokens: [StyleToken] = [],
            layoutHints: LayoutHints = LayoutHints(),
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.inlines = inlines
            self.children = children
            self.styleTokens = styleTokens
            self.layoutHints = layoutHints
            self.metadata = metadata
            self.additionalFields = additionalFields
        }

        public func validate(path: String) throws {
            for (index, token) in styleTokens.enumerated() {
                try token.validate(path: "\(path).styleTokens[\(index)]")
            }

            for (index, child) in children.enumerated() {
                try child.validate(path: "\(path).children[\(index)]")
            }
        }
    }

    public struct RenderModel: Sendable, Equatable, Codable {
        public var schemaVersion: Int
        public var documentId: String
        public var blocks: [RenderBlock]
        public var assets: [RenderAsset]
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            schemaVersion: Int = MarkdownContract.schemaVersion,
            documentId: String,
            blocks: [RenderBlock],
            assets: [RenderAsset] = [],
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.schemaVersion = schemaVersion
            self.documentId = documentId
            self.blocks = blocks
            self.assets = assets
            self.metadata = metadata
            self.additionalFields = additionalFields
        }

        public func validate() throws {
            guard schemaVersion == MarkdownContract.schemaVersion else {
                throw MarkdownContract.ModelError(code: .unsupportedVersion, message: "Unsupported schemaVersion: \(schemaVersion)", path: "schemaVersion")
            }

            for (index, block) in blocks.enumerated() {
                try block.validate(path: "blocks[\(index)]")
            }
        }
    }
}

// MARK: - Kind Codable

extension MarkdownContract.BlockKind: Codable {
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
        case "custom": self = .custom
        default: self = .customRaw(raw)
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
        case .custom: try container.encode("custom")
        case .customRaw(let raw): try container.encode(raw)
        }
    }
}

extension MarkdownContract.InlineKind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw {
        case "text": self = .text
        case "code": self = .code
        case "link": self = .link
        case "image": self = .image
        case "softBreak": self = .softBreak
        case "hardBreak": self = .hardBreak
        case "custom": self = .custom
        default: self = .customRaw(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text: try container.encode("text")
        case .code: try container.encode("code")
        case .link: try container.encode("link")
        case .image: try container.encode("image")
        case .softBreak: try container.encode("softBreak")
        case .hardBreak: try container.encode("hardBreak")
        case .custom: try container.encode("custom")
        case .customRaw(let raw): try container.encode(raw)
        }
    }
}

// MARK: - Validation

extension MarkdownContract.StyleToken {
    func validate(path: String) throws {
        switch value {
        case .color(let color):
            guard color.hasValue else {
                throw MarkdownContract.ModelError(
                    code: .invalidStyleValue,
                    message: "ColorValue requires one of token/hex/rgba",
                    path: "\(path).value"
                )
            }
        default:
            break
        }
    }
}

// MARK: - Unknown field preserving for key structures

extension MarkdownContract.InlineSpan {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case text
        case marks
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MarkdownContract.InlineKind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        marks = try container.decodeIfPresent([MarkdownContract.MarkToken].self, forKey: .marks) ?? []
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.id.rawValue,
            CodingKeys.kind.rawValue,
            CodingKeys.text.rawValue,
            CodingKeys.marks.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(text, forKey: .text)
        try container.encode(marks, forKey: .marks)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.id.rawValue,
            CodingKeys.kind.rawValue,
            CodingKeys.text.rawValue,
            CodingKeys.marks.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}

extension MarkdownContract.RenderBlock {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case inlines
        case children
        case styleTokens
        case layoutHints
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MarkdownContract.BlockKind.self, forKey: .kind)
        inlines = try container.decodeIfPresent([MarkdownContract.InlineSpan].self, forKey: .inlines) ?? []
        children = try container.decodeIfPresent([MarkdownContract.RenderBlock].self, forKey: .children) ?? []
        styleTokens = try container.decodeIfPresent([MarkdownContract.StyleToken].self, forKey: .styleTokens) ?? []
        layoutHints = try container.decodeIfPresent(MarkdownContract.LayoutHints.self, forKey: .layoutHints) ?? MarkdownContract.LayoutHints()
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.id.rawValue,
            CodingKeys.kind.rawValue,
            CodingKeys.inlines.rawValue,
            CodingKeys.children.rawValue,
            CodingKeys.styleTokens.rawValue,
            CodingKeys.layoutHints.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(inlines, forKey: .inlines)
        try container.encode(children, forKey: .children)
        try container.encode(styleTokens, forKey: .styleTokens)
        try container.encode(layoutHints, forKey: .layoutHints)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.id.rawValue,
            CodingKeys.kind.rawValue,
            CodingKeys.inlines.rawValue,
            CodingKeys.children.rawValue,
            CodingKeys.styleTokens.rawValue,
            CodingKeys.layoutHints.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}

extension MarkdownContract.RenderModel {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case documentId
        case blocks
        case assets
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        documentId = try container.decode(String.self, forKey: .documentId)
        blocks = try container.decodeIfPresent([MarkdownContract.RenderBlock].self, forKey: .blocks) ?? []
        assets = try container.decodeIfPresent([MarkdownContract.RenderAsset].self, forKey: .assets) ?? []
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.documentId.rawValue,
            CodingKeys.blocks.rawValue,
            CodingKeys.assets.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(assets, forKey: .assets)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.documentId.rawValue,
            CodingKeys.blocks.rawValue,
            CodingKeys.assets.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}
