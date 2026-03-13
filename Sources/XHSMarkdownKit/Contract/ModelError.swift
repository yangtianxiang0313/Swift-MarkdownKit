import Foundation

extension MarkdownContract {
    public struct ModelError: Error, Sendable, Equatable, Codable {
        public enum Code: String, Sendable, Equatable, Codable {
            case unsupportedVersion = "unsupported_version"
            case schemaInvalid = "schema_invalid"
            case unknownNodeKind = "unknown_node_kind"
            case invalidStyleValue = "invalid_style_value"
            case requiredFieldMissing = "required_field_missing"
        }

        public var code: String
        public var message: String
        public var path: String?
        public var details: [String: Value]

        public init(
            code: Code,
            message: String,
            path: String? = nil,
            details: [String: Value] = [:]
        ) {
            self.code = code.rawValue
            self.message = message
            self.path = path
            self.details = details
        }

        public init(
            code: String,
            message: String,
            path: String? = nil,
            details: [String: Value] = [:]
        ) {
            self.code = code
            self.message = message
            self.path = path
            self.details = details
        }
    }
}

extension MarkdownContract.ModelError {
    static func schemaInvalid(from error: Error) -> MarkdownContract.ModelError {
        MarkdownContract.ModelError(
            code: .schemaInvalid,
            message: "Schema decoding failed: \(error)",
            details: ["error": .string(String(describing: error))]
        )
    }
}
