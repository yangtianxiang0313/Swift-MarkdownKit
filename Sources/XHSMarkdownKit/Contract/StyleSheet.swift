import Foundation

extension MarkdownContract {
    public struct ThemeTokens: Sendable, Equatable, Codable {
        public var values: [String: StyleValue]

        public init(values: [String: StyleValue] = [:]) {
            self.values = values
        }
    }

    public struct NodeStyleRule: Sendable, Equatable, Codable {
        public var inheritFromParent: Bool
        public var themeTokenRefs: [String]
        public var styleTokens: [StyleToken]

        public init(
            inheritFromParent: Bool = false,
            themeTokenRefs: [String] = [],
            styleTokens: [StyleToken] = []
        ) {
            self.inheritFromParent = inheritFromParent
            self.themeTokenRefs = themeTokenRefs
            self.styleTokens = styleTokens
        }
    }

    public struct NodeStyleSheet: Sendable, Equatable, Codable {
        public var byNodeKind: [String: NodeStyleRule]
        public var byCustomElementName: [String: NodeStyleRule]
        public var defaultRule: NodeStyleRule?

        public init(
            byNodeKind: [String: NodeStyleRule] = [:],
            byCustomElementName: [String: NodeStyleRule] = [:],
            defaultRule: NodeStyleRule? = nil
        ) {
            self.byNodeKind = byNodeKind
            self.byCustomElementName = byCustomElementName
            self.defaultRule = defaultRule
        }
    }
}
