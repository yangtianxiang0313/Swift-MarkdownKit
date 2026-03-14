import Foundation
@testable import XHSMarkdownKit
import XHSMarkdownAdapterMarkdownn

enum ExtensionNodeTestSupport {
    static let calloutKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "callout"))
    static let tabsKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "tabs"))
    static let mentionKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "mention"))
    static let spoilerKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "spoiler"))

    static func makeNodeSpecRegistry() -> MarkdownContract.NodeSpecRegistry {
        let registry = MarkdownContract.NodeSpecRegistry.core()

        registry.register(.init(
            kind: calloutKind,
            role: .blockLeaf,
            childPolicy: .none,
            parseAliases: [.init(sourceKind: .directive, name: "Callout")]
        ))

        registry.register(.init(
            kind: tabsKind,
            role: .blockContainer,
            childPolicy: .blockOnly(minChildren: 1),
            parseAliases: [.init(sourceKind: .directive, name: "Tabs")]
        ))

        registry.register(.init(
            kind: mentionKind,
            role: .inlineLeaf,
            childPolicy: .none,
            parseAliases: [.init(sourceKind: .htmlTag, name: "mention")]
        ))

        registry.register(.init(
            kind: spoilerKind,
            role: .inlineContainer,
            childPolicy: .inlineOnly(minChildren: 0),
            parseAliases: [.init(sourceKind: .htmlTag, name: "spoiler")]
        ))

        return registry
    }

    static func makeRendererRegistry() -> MarkdownContract.CanonicalRendererRegistry {
        let registry = MarkdownContract.CanonicalRendererRegistry.makeDefault()

        registry.registerBlockRenderer(for: calloutKind) { node, context, reg in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: calloutKind,
                inlines: [
                    .init(
                        id: "\(node.id).title",
                        kind: .text,
                        text: "[CALLOUT]"
                    )
                ],
                styleTokens: [],
                layoutHints: .init(),
                metadata: regExtensionMetadata(from: node, type: "callout")
            )]
        }

        registry.registerBlockRenderer(for: tabsKind) { node, context, reg in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: tabsKind,
                inlines: [],
                children: try reg.renderBlockChildren(of: node, context: context),
                styleTokens: [],
                layoutHints: .init(),
                metadata: regExtensionMetadata(from: node, type: "tabs")
            )]
        }

        registry.registerInlineRenderer(for: mentionKind) { node, _, _ in
            let userID: String
            if case let .object(attributes)? = node.attrs["attributes"], case let .string(value)? = attributes["userId"] {
                userID = value
            } else {
                userID = "unknown"
            }
            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: mentionKind,
                text: "@\(userID)",
                metadata: ["attrs": .object(node.attrs)]
            )]
        }

        registry.registerInlineRenderer(for: spoilerKind) { node, context, reg in
            let children = try reg.renderInlineChildren(of: node, context: context)
            if children.isEmpty {
                let raw: String
                if case let .string(value)? = node.attrs["raw"] {
                    raw = value
                } else {
                    raw = node.source.raw ?? ""
                }
                return [MarkdownContract.InlineSpan(
                    id: node.id,
                    kind: .text,
                    text: raw,
                    marks: [.init(name: "spoiler")]
                )]
            }
            return children.map { span in
                var updated = span
                updated.marks.append(.init(name: "spoiler"))
                return updated
            }
        }

        return registry
    }

    static func makeEngine() -> MarkdownContractEngine {
        let specs = makeNodeSpecRegistry()
        let parser = XYMarkdownContractParser(nodeSpecRegistry: specs)
        let renderer = MarkdownContract.DefaultCanonicalRenderer(
            registry: makeRendererRegistry(),
            nodeSpecRegistry: specs
        )
        let rewrite = MarkdownContract.CanonicalRewritePipeline(nodeSpecRegistry: specs)
        return MarkdownContractEngine(parser: parser, rewritePipeline: rewrite, renderer: renderer)
    }

    private static func regExtensionMetadata(from node: MarkdownContract.CanonicalNode, type: String) -> [String: MarkdownContract.Value] {
        [
            "extType": .string(type),
            "extKind": .string(node.kind.rawValue)
        ]
    }
}
