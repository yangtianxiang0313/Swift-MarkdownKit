import Foundation

extension MarkdownContract {
    public enum RewritePhase: Sendable, Equatable {
        case preChildren
        case postChildren
    }

    public struct RewriteContext: Sendable, Equatable {
        public let path: [Int]
        public let phase: RewritePhase

        public init(path: [Int], phase: RewritePhase) {
            self.path = path
            self.phase = phase
        }
    }

    public struct RewriteRule {
        public typealias Transform = @Sendable (_ node: CanonicalNode, _ context: RewriteContext) -> CanonicalNode

        public let id: String
        public let priority: Int
        public let phase: RewritePhase
        private let transform: Transform

        public init(
            id: String,
            priority: Int = 0,
            phase: RewritePhase = .preChildren,
            transform: @escaping Transform
        ) {
            self.id = id
            self.priority = priority
            self.phase = phase
            self.transform = transform
        }

        func apply(to node: CanonicalNode, context: RewriteContext) -> CanonicalNode {
            transform(node, context)
        }
    }

    public struct CanonicalRewritePipeline {
        public let rules: [RewriteRule]
        public let nodeSpecRegistry: NodeSpecRegistry
        private let treeValidator: TreeValidator

        public init(
            rules: [RewriteRule] = [],
            nodeSpecRegistry: NodeSpecRegistry = .core()
        ) {
            self.rules = rules
            self.nodeSpecRegistry = nodeSpecRegistry
            self.treeValidator = TreeValidator(registry: nodeSpecRegistry)
        }

        public func rewrite(_ document: CanonicalDocument) throws -> CanonicalDocument {
            try document.validate()
            try treeValidator.validate(document: document)

            let sorted = rules.sorted {
                if $0.priority == $1.priority {
                    return $0.id < $1.id
                }
                // Lower priority runs earlier so higher priority has the final override.
                return $0.priority < $1.priority
            }

            let rewrittenRoot = rewriteNode(document.root, path: [], rules: sorted)
            var rewritten = document
            rewritten.root = rewrittenRoot
            try rewritten.validate()
            try treeValidator.validate(document: rewritten)
            return rewritten
        }

        private func rewriteNode(
            _ node: CanonicalNode,
            path: [Int],
            rules: [RewriteRule]
        ) -> CanonicalNode {
            let preContext = RewriteContext(path: path, phase: .preChildren)
            var current = applyRules(node, context: preContext, rules: rules)

            let rewrittenChildren = current.children.enumerated().map { index, child in
                rewriteNode(child, path: path + [index], rules: rules)
            }
            current.children = rewrittenChildren

            let postContext = RewriteContext(path: path, phase: .postChildren)
            current = applyRules(current, context: postContext, rules: rules)

            return current
        }

        private func applyRules(
            _ node: CanonicalNode,
            context: RewriteContext,
            rules: [RewriteRule]
        ) -> CanonicalNode {
            var current = node
            for rule in rules where rule.phase == context.phase {
                current = rule.apply(to: current, context: context)
            }
            return current
        }
    }
}
