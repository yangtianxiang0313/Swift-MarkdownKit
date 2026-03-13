import Foundation

extension MarkdownContract {
    public enum Value: Sendable, Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case object([String: Value])
        case array([Value])
        case null
    }
}

extension MarkdownContract.Value: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "string":
            self = .string(try container.decode(String.self, forKey: .value))
        case "int":
            self = .int(try container.decode(Int.self, forKey: .value))
        case "double":
            self = .double(try container.decode(Double.self, forKey: .value))
        case "bool":
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case "object":
            self = .object(try container.decode([String: MarkdownContract.Value].self, forKey: .value))
        case "array":
            self = .array(try container.decode([MarkdownContract.Value].self, forKey: .value))
        case "null":
            self = .null
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported Value.type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode("int", forKey: .type)
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode("double", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode("bool", forKey: .type)
            try container.encode(value, forKey: .value)
        case .object(let value):
            try container.encode("object", forKey: .type)
            try container.encode(value, forKey: .value)
        case .array(let value):
            try container.encode("array", forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode("null", forKey: .type)
            try container.encodeNil(forKey: .value)
        }
    }
}

extension MarkdownContract {
    public struct ColorValue: Sendable, Equatable, Codable {
        public struct RGBA: Sendable, Equatable, Codable {
            public var r: Double
            public var g: Double
            public var b: Double
            public var a: Double

            public init(r: Double, g: Double, b: Double, a: Double) {
                self.r = r
                self.g = g
                self.b = b
                self.a = a
            }
        }

        public struct FlatColor: Sendable, Equatable, Codable {
            public var token: String?
            public var hex: String?
            public var rgba: RGBA?

            public init(token: String? = nil, hex: String? = nil, rgba: RGBA? = nil) {
                self.token = token
                self.hex = hex
                self.rgba = rgba
            }
        }

        public struct Appearance: Sendable, Equatable, Codable {
            public var light: FlatColor?
            public var dark: FlatColor?

            public init(light: FlatColor? = nil, dark: FlatColor? = nil) {
                self.light = light
                self.dark = dark
            }
        }

        public var token: String?
        public var hex: String?
        public var rgba: RGBA?
        public var appearance: Appearance?

        public init(token: String? = nil, hex: String? = nil, rgba: RGBA? = nil, appearance: Appearance? = nil) {
            self.token = token
            self.hex = hex
            self.rgba = rgba
            self.appearance = appearance
        }

        public var hasValue: Bool {
            token != nil || hex != nil || rgba != nil
        }
    }

    public struct TypographyValue: Sendable, Equatable, Codable {
        public var family: String
        public var size: Double
        public var weight: Int
        public var lineHeight: Double?
        public var letterSpacing: Double?

        public init(
            family: String,
            size: Double,
            weight: Int,
            lineHeight: Double? = nil,
            letterSpacing: Double? = nil
        ) {
            self.family = family
            self.size = size
            self.weight = weight
            self.lineHeight = lineHeight
            self.letterSpacing = letterSpacing
        }
    }

    public struct SpacingValue: Sendable, Equatable, Codable {
        public var top: Double
        public var right: Double
        public var bottom: Double
        public var left: Double

        public init(top: Double, right: Double, bottom: Double, left: Double) {
            self.top = top
            self.right = right
            self.bottom = bottom
            self.left = left
        }
    }

    public struct BorderValue: Sendable, Equatable, Codable {
        public var width: Double
        public var color: ColorValue
        public var style: String

        public init(width: Double, color: ColorValue, style: String) {
            self.width = width
            self.color = color
            self.style = style
        }
    }

    public struct ShadowValue: Sendable, Equatable, Codable {
        public var x: Double
        public var y: Double
        public var blur: Double
        public var spread: Double
        public var color: ColorValue

        public init(x: Double, y: Double, blur: Double, spread: Double, color: ColorValue) {
            self.x = x
            self.y = y
            self.blur = blur
            self.spread = spread
            self.color = color
        }
    }

    public enum StyleValue: Sendable, Equatable {
        case color(ColorValue)
        case typography(TypographyValue)
        case spacing(SpacingValue)
        case radius(Double)
        case border(BorderValue)
        case shadow(ShadowValue)
        case opacity(Double)
        case number(Double)
        case bool(Bool)
        case string(String)
        case object([String: Value])
        case array([Value])
        case null
    }
}

extension MarkdownContract.StyleValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "color":
            self = .color(try container.decode(MarkdownContract.ColorValue.self, forKey: .value))
        case "typography":
            self = .typography(try container.decode(MarkdownContract.TypographyValue.self, forKey: .value))
        case "spacing":
            self = .spacing(try container.decode(MarkdownContract.SpacingValue.self, forKey: .value))
        case "radius":
            self = .radius(try container.decode(Double.self, forKey: .value))
        case "border":
            self = .border(try container.decode(MarkdownContract.BorderValue.self, forKey: .value))
        case "shadow":
            self = .shadow(try container.decode(MarkdownContract.ShadowValue.self, forKey: .value))
        case "opacity":
            self = .opacity(try container.decode(Double.self, forKey: .value))
        case "number":
            self = .number(try container.decode(Double.self, forKey: .value))
        case "bool":
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case "string":
            self = .string(try container.decode(String.self, forKey: .value))
        case "object":
            self = .object(try container.decode([String: MarkdownContract.Value].self, forKey: .value))
        case "array":
            self = .array(try container.decode([MarkdownContract.Value].self, forKey: .value))
        case "null":
            self = .null
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported StyleValue.type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .color(let value):
            try container.encode("color", forKey: .type)
            try container.encode(value, forKey: .value)
        case .typography(let value):
            try container.encode("typography", forKey: .type)
            try container.encode(value, forKey: .value)
        case .spacing(let value):
            try container.encode("spacing", forKey: .type)
            try container.encode(value, forKey: .value)
        case .radius(let value):
            try container.encode("radius", forKey: .type)
            try container.encode(value, forKey: .value)
        case .border(let value):
            try container.encode("border", forKey: .type)
            try container.encode(value, forKey: .value)
        case .shadow(let value):
            try container.encode("shadow", forKey: .type)
            try container.encode(value, forKey: .value)
        case .opacity(let value):
            try container.encode("opacity", forKey: .type)
            try container.encode(value, forKey: .value)
        case .number(let value):
            try container.encode("number", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode("bool", forKey: .type)
            try container.encode(value, forKey: .value)
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .object(let value):
            try container.encode("object", forKey: .type)
            try container.encode(value, forKey: .value)
        case .array(let value):
            try container.encode("array", forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode("null", forKey: .type)
            try container.encodeNil(forKey: .value)
        }
    }
}
