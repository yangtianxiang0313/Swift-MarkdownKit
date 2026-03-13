import Foundation

extension MarkdownContract {
    public struct RectValue: Sendable, Equatable, Codable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct SceneEntity: Sendable, Equatable, Codable {
        public var id: String
        public var kind: String
        public var parentId: String?
        public var frame: RectValue?
        public var metadata: [String: Value]

        public init(
            id: String,
            kind: String,
            parentId: String? = nil,
            frame: RectValue? = nil,
            metadata: [String: Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.parentId = parentId
            self.frame = frame
            self.metadata = metadata
        }
    }

    public struct LayoutTreeNode: Sendable, Equatable, Codable {
        public var id: String
        public var children: [LayoutTreeNode]

        public init(id: String, children: [LayoutTreeNode] = []) {
            self.id = id
            self.children = children
        }
    }

    public struct SceneSnapshot: Sendable, Equatable, Codable {
        public var schemaVersion: Int
        public var sceneId: String
        public var entities: [SceneEntity]
        public var layoutTree: LayoutTreeNode?
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            schemaVersion: Int = MarkdownContract.schemaVersion,
            sceneId: String,
            entities: [SceneEntity],
            layoutTree: LayoutTreeNode? = nil,
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.schemaVersion = schemaVersion
            self.sceneId = sceneId
            self.entities = entities
            self.layoutTree = layoutTree
            self.metadata = metadata
            self.additionalFields = additionalFields
        }

        public func validate() throws {
            guard schemaVersion == MarkdownContract.schemaVersion else {
                throw MarkdownContract.ModelError(code: .unsupportedVersion, message: "Unsupported schemaVersion: \(schemaVersion)", path: "schemaVersion")
            }
        }
    }

    public struct AnimationIntent: Sendable, Equatable, Codable {
        public var entityId: String
        public var type: String
        public var from: Value?
        public var to: Value?
        public var params: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            entityId: String,
            type: String,
            from: Value? = nil,
            to: Value? = nil,
            params: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.entityId = entityId
            self.type = type
            self.from = from
            self.to = to
            self.params = params
            self.additionalFields = additionalFields
        }
    }

    public struct TimelineTrack: Sendable, Equatable, Codable {
        public var id: String
        public var entityIds: [String]
        public var metadata: [String: Value]

        public init(id: String, entityIds: [String], metadata: [String: Value] = [:]) {
            self.id = id
            self.entityIds = entityIds
            self.metadata = metadata
        }
    }

    public struct TimelinePhase: Sendable, Equatable, Codable {
        public var id: String
        public var name: String
        public var trackIds: [String]
        public var metadata: [String: Value]

        public init(id: String, name: String, trackIds: [String], metadata: [String: Value] = [:]) {
            self.id = id
            self.name = name
            self.trackIds = trackIds
            self.metadata = metadata
        }
    }

    public struct TimelineConstraint: Sendable, Equatable, Codable {
        public var kind: String
        public var from: String
        public var to: String
        public var metadata: [String: Value]

        public init(kind: String, from: String, to: String, metadata: [String: Value] = [:]) {
            self.kind = kind
            self.from = from
            self.to = to
            self.metadata = metadata
        }
    }

    public struct TimelineGraph: Sendable, Equatable, Codable {
        public var schemaVersion: Int
        public var tracks: [TimelineTrack]
        public var phases: [TimelinePhase]
        public var constraints: [TimelineConstraint]
        public var metadata: [String: Value]
        public var additionalFields: [String: Value]

        public init(
            schemaVersion: Int = MarkdownContract.schemaVersion,
            tracks: [TimelineTrack],
            phases: [TimelinePhase],
            constraints: [TimelineConstraint],
            metadata: [String: Value] = [:],
            additionalFields: [String: Value] = [:]
        ) {
            self.schemaVersion = schemaVersion
            self.tracks = tracks
            self.phases = phases
            self.constraints = constraints
            self.metadata = metadata
            self.additionalFields = additionalFields
        }

        public func validate() throws {
            guard schemaVersion == MarkdownContract.schemaVersion else {
                throw MarkdownContract.ModelError(code: .unsupportedVersion, message: "Unsupported schemaVersion: \(schemaVersion)", path: "schemaVersion")
            }
        }
    }

    public struct AnimationProgress: Sendable, Equatable, Codable {
        public var version: Int
        public var running: Bool
        public var completedSteps: Int
        public var totalSteps: Int
        public var displayedUnits: Double?
        public var totalUnits: Double?

        public init(
            version: Int,
            running: Bool,
            completedSteps: Int,
            totalSteps: Int,
            displayedUnits: Double? = nil,
            totalUnits: Double? = nil
        ) {
            self.version = version
            self.running = running
            self.completedSteps = completedSteps
            self.totalSteps = totalSteps
            self.displayedUnits = displayedUnits
            self.totalUnits = totalUnits
        }
    }
}

// MARK: - Unknown field preserving for key structures

extension MarkdownContract.SceneSnapshot {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sceneId
        case entities
        case layoutTree
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        sceneId = try container.decode(String.self, forKey: .sceneId)
        entities = try container.decodeIfPresent([MarkdownContract.SceneEntity].self, forKey: .entities) ?? []
        layoutTree = try container.decodeIfPresent(MarkdownContract.LayoutTreeNode.self, forKey: .layoutTree)
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.sceneId.rawValue,
            CodingKeys.entities.rawValue,
            CodingKeys.layoutTree.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(sceneId, forKey: .sceneId)
        try container.encode(entities, forKey: .entities)
        try container.encodeIfPresent(layoutTree, forKey: .layoutTree)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.sceneId.rawValue,
            CodingKeys.entities.rawValue,
            CodingKeys.layoutTree.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}

extension MarkdownContract.AnimationIntent {
    private enum CodingKeys: String, CodingKey {
        case entityId
        case type
        case from
        case to
        case params
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityId = try container.decode(String.self, forKey: .entityId)
        type = try container.decode(String.self, forKey: .type)
        from = try container.decodeIfPresent(MarkdownContract.Value.self, forKey: .from)
        to = try container.decodeIfPresent(MarkdownContract.Value.self, forKey: .to)
        params = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .params) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.entityId.rawValue,
            CodingKeys.type.rawValue,
            CodingKeys.from.rawValue,
            CodingKeys.to.rawValue,
            CodingKeys.params.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entityId, forKey: .entityId)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(from, forKey: .from)
        try container.encodeIfPresent(to, forKey: .to)
        try container.encode(params, forKey: .params)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.entityId.rawValue,
            CodingKeys.type.rawValue,
            CodingKeys.from.rawValue,
            CodingKeys.to.rawValue,
            CodingKeys.params.rawValue
        ])
    }
}

extension MarkdownContract.TimelineGraph {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case tracks
        case phases
        case constraints
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        tracks = try container.decodeIfPresent([MarkdownContract.TimelineTrack].self, forKey: .tracks) ?? []
        phases = try container.decodeIfPresent([MarkdownContract.TimelinePhase].self, forKey: .phases) ?? []
        constraints = try container.decodeIfPresent([MarkdownContract.TimelineConstraint].self, forKey: .constraints) ?? []
        metadata = try container.decodeIfPresent([String: MarkdownContract.Value].self, forKey: .metadata) ?? [:]
        additionalFields = try MarkdownContract.decodeAdditionalFields(from: decoder, knownKeys: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.tracks.rawValue,
            CodingKeys.phases.rawValue,
            CodingKeys.constraints.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(phases, forKey: .phases)
        try container.encode(constraints, forKey: .constraints)
        try container.encode(metadata, forKey: .metadata)

        try MarkdownContract.encodeAdditionalFields(additionalFields, to: encoder, excluding: [
            CodingKeys.schemaVersion.rawValue,
            CodingKeys.tracks.rawValue,
            CodingKeys.phases.rawValue,
            CodingKeys.constraints.rawValue,
            CodingKeys.metadata.rawValue
        ])
    }
}
