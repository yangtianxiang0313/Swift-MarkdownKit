import Foundation

public enum MarkdownContract {
    public static let schemaVersion: Int = 1
}

extension MarkdownContract {
    public struct DynamicCodingKey: CodingKey, Hashable {
        public let stringValue: String
        public let intValue: Int?

        public init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        public init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }

        public init(_ stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
    }

    static func decodeAdditionalFields(
        from decoder: Decoder,
        knownKeys: Set<String>
    ) throws -> [String: Value] {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var additional: [String: Value] = [:]

        for key in container.allKeys where !knownKeys.contains(key.stringValue) {
            additional[key.stringValue] = try container.decode(Value.self, forKey: key)
        }

        return additional
    }

    static func encodeAdditionalFields(
        _ additionalFields: [String: Value],
        to encoder: Encoder,
        excluding knownKeys: Set<String>
    ) throws {
        guard !additionalFields.isEmpty else { return }

        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in additionalFields where !knownKeys.contains(key) {
            try container.encode(value, forKey: DynamicCodingKey(key))
        }
    }
}
