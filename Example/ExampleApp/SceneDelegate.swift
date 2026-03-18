import UIKit
import XHSMarkdownKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        let tabBarController = UITabBarController()
        
        // 预览页面
        let previewVC = MarkdownPreviewViewController()
        previewVC.tabBarItem = UITabBarItem(
            title: "预览",
            image: UIImage(systemName: "doc.text"),
            selectedImage: UIImage(systemName: "doc.text.fill")
        )
        
        // 主题切换页面
        let themeVC = ThemeSwitchViewController()
        themeVC.tabBarItem = UITabBarItem(
            title: "主题",
            image: UIImage(systemName: "paintpalette"),
            selectedImage: UIImage(systemName: "paintpalette.fill")
        )
        
        // 自定义渲染器演示页面
        let customVC = CustomRendererDemoViewController()
        customVC.tabBarItem = UITabBarItem(
            title: "自定义",
            image: UIImage(systemName: "slider.horizontal.3"),
            selectedImage: UIImage(systemName: "slider.horizontal.3")
        )
        
        // 流式渲染演示页面
        let streamingVC = StreamingDemoViewController()
        streamingVC.tabBarItem = UITabBarItem(
            title: "流式+动画",
            image: UIImage(systemName: "play.circle"),
            selectedImage: UIImage(systemName: "play.circle.fill")
        )

        tabBarController.viewControllers = [
            UINavigationController(rootViewController: previewVC),
            UINavigationController(rootViewController: themeVC),
            UINavigationController(rootViewController: customVC),
            UINavigationController(rootViewController: streamingVC)
        ]
        
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
    }
}

enum ExampleMarkdownRuntime {
    static let calloutKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "callout"))
    static let tabsKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "tabs"))
    static let heroKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "hero"))
    static let panelKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "panel"))
    static let mentionKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "mention"))
    static let spoilerKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "spoiler"))
    static let badgeKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "badge"))
    static let chipKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "chip"))
    static let citeKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "cite"))
    static let thinkKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "think"))

    static func makeConfiguredContainer(theme: MarkdownTheme = .default) -> MarkdownContainerView {
        let container = MarkdownContainerView(theme: theme)
        _ = installMarkdownn(into: container)
        container.contractRenderAdapter = makeExampleRenderAdapter()
        return container
    }

    static func makeStreamingEngine() -> MarkdownContractEngine? {
        #if canImport(XYMarkdown)
        let nodeSpecs = makeNodeSpecRegistry()
        let canonicalRegistry = makeCanonicalRendererRegistry()
        let rewritePipeline = MarkdownContract.CanonicalRewritePipeline(nodeSpecRegistry: nodeSpecs)
        return MarkdownnAdapter.makeEngine(
            rewritePipeline: rewritePipeline,
            nodeSpecRegistry: nodeSpecs,
            canonicalRendererRegistry: canonicalRegistry
        )
        #else
        return nil
        #endif
    }

    @MainActor
    static func makeRuntime(
        renderStore: MarkdownRenderStore = MarkdownRenderStore()
    ) -> MarkdownRuntime {
        let runtime = MarkdownRuntime(
            behaviorRegistry: makeBehaviorRegistry(),
            streamingEngine: makeStreamingEngine(),
            renderStore: renderStore
        )
        runtime.persistenceAdapter = runtimePersistenceAdapter
        runtime.dataBindingAdapter = runtimeDataBindingAdapter
        return runtime
    }

    static func makeRewritePipeline() -> MarkdownContract.CanonicalRewritePipeline {
        MarkdownContract.CanonicalRewritePipeline(nodeSpecRegistry: makeNodeSpecRegistry())
    }

    static func makeExampleRenderAdapter() -> MarkdownContract.RenderModelUIKitAdapter {
        let adapter = MarkdownContract.RenderModelUIKitAdapter(
            mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
            blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
        )

        adapter.registerBlockMapper(forExtension: calloutKind.rawValue) { block, _, adapter in
            let title = block.contractAttrString(for: "title") ?? "Callout"
            let attributed = NSAttributedString(
                string: "CALLOUT  \(title)",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.systemBlue
                ]
            )
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "callout.custom",
                attributedText: attributed,
                spacingAfter: 10
            )
            return [.mergeSegment(segment)]
        }

        adapter.registerBlockMapper(forExtension: heroKind.rawValue) { block, _, adapter in
            let title = block.inlines.first(where: { $0.id.hasSuffix(".title") })?.text
                ?? block.contractAttrString(for: "title")
                ?? "Hero"
            let subtitle = block.inlines.first(where: { $0.id.hasSuffix(".desc") })?.text
                ?? block.contractAttrString(for: "subtitle")
                ?? ""
            let text = subtitle.isEmpty ? "HERO  \(title)" : "HERO  \(title)\n\(subtitle)"
            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.systemIndigo
                ]
            )
            if !subtitle.isEmpty {
                let full = text as NSString
                let range = full.range(of: subtitle)
                if range.location != NSNotFound {
                    attributed.addAttributes(
                        [
                            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                            .foregroundColor: UIColor.secondaryLabel
                        ],
                        range: range
                    )
                }
            }
            let segment = adapter.makeMergeTextSegment(
                sourceBlockID: block.id,
                kind: "hero.custom",
                attributedText: attributed,
                spacingAfter: 12,
                forceMergeBreakAfter: true
            )
            return [.mergeSegment(segment)]
        }

        adapter.registerBlockMapper(forExtension: panelKind.rawValue) { block, context, adapter in
            let panelStyle = block.contractAttrString(for: "style") ?? "default"
            let title = NSAttributedString(
                string: "PANEL  [\(panelStyle)]",
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.systemOrange
                ]
            )
            let header = adapter.makeMergeTextSegment(
                sourceBlockID: "\(block.id).panelHeader",
                kind: "panel.custom.header",
                attributedText: title,
                spacingAfter: 6,
                metadata: block.metadata,
                forceMergeBreakAfter: true
            )
            let children = try block.children.flatMap {
                try adapter.renderBlockAsDefault($0, context: context)
            }
            return [.mergeSegment(header)] + children
        }

        adapter.registerBlockMapper(forExtension: tabsKind.rawValue) { block, context, adapter in
            let title = NSAttributedString(
                string: "TABS",
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.systemTeal
                ]
            )
            let header = adapter.makeMergeTextSegment(
                sourceBlockID: "\(block.id).tabsHeader",
                kind: "tabs.custom.header",
                attributedText: title,
                spacingAfter: 4,
                metadata: block.metadata,
                forceMergeBreakAfter: true
            )
            let children = try block.children.flatMap {
                try adapter.renderBlockAsDefault($0, context: context)
            }
            return [.mergeSegment(header)] + children
        }

        adapter.registerBlockMapper(forExtension: thinkKind.rawValue) { block, context, adapter in
            let thinkStateKey = block.contractAttrString(for: "id")
                ?? block.contractAttrString(for: "businessID")
                ?? block.id
            let collapsed = uiStateBool(for: block, key: "collapsed") ?? false
            let toggleText = collapsed ? "展开" : "折叠"

            let header = NSMutableAttributedString(
                string: "Thinking  [\(toggleText)]",
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
            let toggleRange = (header.string as NSString).range(of: "[\(toggleText)]")
            if toggleRange.location != NSNotFound {
                header.addAttributes(
                    [
                        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.systemBlue
                    ],
                    range: toggleRange
                )
            }

            header.addAttributes(
                [
                    .link: "xhs-think://\(thinkStateKey)",
                    .xhsInteractionNodeID: block.id,
                    .xhsInteractionNodeKind: block.kind.rawValue,
                    .xhsInteractionStateKey: thinkStateKey
                ],
                range: NSRange(location: 0, length: header.length)
            )

            var results: [MarkdownContract.BlockMappingResult] = [
                .mergeSegment(
                    adapter.makeMergeTextSegment(
                        sourceBlockID: "\(block.id).think.header",
                        kind: "think.header",
                        attributedText: header,
                        spacingAfter: collapsed ? 8 : 6,
                        metadata: block.metadata,
                        forceMergeBreakAfter: true
                    )
                )
            ]

            if !collapsed {
                let children = try block.children.flatMap {
                    try adapter.renderBlockAsDefault($0, context: context)
                }
                results.append(contentsOf: children.map(tintThinkBody))
            }
            return results
        }

        adapter.registerInlineRenderer(forExtension: mentionKind.rawValue) { span, _, _, _ in
            let text = span.contractAttrString(for: "userId").map { "@\($0)" } ?? span.text
            return NSAttributedString(
                string: " \(text) ",
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.systemPink
                ]
            )
        }

        adapter.registerInlineRenderer(forExtension: badgeKind.rawValue) { span, _, _, _ in
            let text = span.text.isEmpty ? "BADGE" : span.text
            return NSAttributedString(
                string: " [\(text)] ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.systemRed
                ]
            )
        }

        adapter.registerInlineRenderer(forExtension: chipKind.rawValue) { span, _, _, _ in
            let text = span.text.isEmpty ? "chip" : span.text
            return NSAttributedString(
                string: " <\(text)> ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.systemTeal
                ]
            )
        }

        adapter.registerInlineRenderer(forExtension: citeKind.rawValue) { span, _, _, _ in
            makeCiteInline(span: span)
        }

        adapter.customMarkAttributeResolver = { mark, attributes, _, _ in
            if mark.name == "spoiler" {
                attributes[.backgroundColor] = UIColor.systemGray4.withAlphaComponent(0.7)
                attributes[.foregroundColor] = UIColor.systemGray
                attributes[.xhsBaseForegroundColor] = UIColor.systemGray
            }
        }

        return adapter
    }

    @discardableResult
    static func installMarkdownn(into container: MarkdownContainerView) -> Bool {
        #if canImport(XYMarkdown)
        let nodeSpecs = makeNodeSpecRegistry()
        let canonicalRegistry = makeCanonicalRendererRegistry()

        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        MarkdownnAdapter.install(
            into: registry,
            nodeSpecRegistry: nodeSpecs,
            canonicalRendererRegistry: canonicalRegistry
        )
        container.contractKit = MarkdownContract.UniversalMarkdownKit(registry: registry)
        return true
        #else
        // Root pod (UIKit default) has no parser plugin; keep predictable "parser missing" behavior.
        container.contractKit = MarkdownContract.UniversalMarkdownKit()
        return false
        #endif
    }

    private static func makeNodeSpecRegistry() -> MarkdownContract.NodeSpecRegistry {
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
            kind: heroKind,
            role: .blockLeaf,
            childPolicy: .none,
            parseAliases: [.init(sourceKind: .directive, name: "Hero")]
        ))
        registry.register(.init(
            kind: panelKind,
            role: .blockContainer,
            childPolicy: .blockOnly(minChildren: 0),
            parseAliases: [.init(sourceKind: .directive, name: "Panel")]
        ))

        makeTagSchemaRegistry().install(into: registry)

        return registry
    }

    private static func makeTagSchemaRegistry() -> MarkdownContract.TagSchemaRegistry {
        MarkdownContract.TagSchemaRegistry(schemas: [
            .init(
                tagName: "mention",
                nodeKind: mentionKind,
                role: .inlineLeaf,
                childPolicy: .none,
                pairingMode: .selfClosing
            ),
            .init(
                tagName: "spoiler",
                nodeKind: spoilerKind,
                role: .inlineContainer,
                childPolicy: .inlineOnly(minChildren: 0),
                pairingMode: .both
            ),
            .init(
                tagName: "cite",
                nodeKind: citeKind,
                role: .inlineContainer,
                childPolicy: .inlineOnly(minChildren: 0),
                pairingMode: .paired
            ),
            .init(
                tagName: "badge",
                nodeKind: badgeKind,
                role: .inlineLeaf,
                childPolicy: .none,
                pairingMode: .selfClosing
            ),
            .init(
                tagName: "chip",
                nodeKind: chipKind,
                role: .inlineContainer,
                childPolicy: .inlineOnly(minChildren: 0),
                pairingMode: .both
            ),
            .init(
                tagName: "think",
                nodeKind: thinkKind,
                role: .blockContainer,
                childPolicy: .blockOnly(minChildren: 0),
                pairingMode: .paired
            )
        ])
    }

    private static func makeCanonicalRendererRegistry() -> MarkdownContract.CanonicalRendererRegistry {
        let registry = MarkdownContract.CanonicalRendererRegistry.makeDefault()

        registry.registerBlockRenderer(for: calloutKind) { node, _, _ in
            let title = node.attrs["title"]?.stringValue ?? "Callout"
            return [MarkdownContract.RenderBlock(
                id: node.id,
                kind: calloutKind,
                inlines: [
                    .init(
                        id: "\(node.id).title",
                        kind: .text,
                        text: "[CALLOUT] \(title)"
                    )
                ],
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerBlockRenderer(for: tabsKind) { node, context, reg in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: tabsKind,
                children: try reg.renderBlockChildren(of: node, context: context),
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerBlockRenderer(for: heroKind) { node, _, _ in
            let title = node.attrs["title"]?.stringValue ?? "Hero"
            let subtitle = node.attrs["subtitle"]?.stringValue ?? "subtitle"
            return [MarkdownContract.RenderBlock(
                id: node.id,
                kind: heroKind,
                inlines: [
                    .init(id: "\(node.id).title", kind: .text, text: "HERO · \(title)"),
                    .init(id: "\(node.id).subtitle", kind: .softBreak, text: "\n"),
                    .init(id: "\(node.id).desc", kind: .text, text: subtitle)
                ],
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerBlockRenderer(for: panelKind) { node, context, reg in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: panelKind,
                children: try reg.renderBlockChildren(of: node, context: context),
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue),
                    "panelStyle": .string(node.attrs["style"]?.stringValue ?? "default")
                ]
            )]
        }

        registry.registerInlineRenderer(for: mentionKind) { node, _, _ in
            let userID: String
            if case let .object(attributes)? = node.attrs["attributes"],
               case let .string(value)? = attributes["userId"] {
                userID = value
            } else {
                userID = "unknown"
            }

            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: mentionKind,
                text: "@\(userID)",
                metadata: [
                    "attrs": .object(node.attrs),
                    "userId": .string(userID),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerInlineRenderer(for: spoilerKind) { node, context, reg in
            let renderedChildren = try reg.renderInlineChildren(of: node, context: context)
            let wrappedChildren = renderedChildren.map { span in
                var updated = span
                updated.marks.append(.init(name: "spoiler"))
                return updated
            }
            if !wrappedChildren.isEmpty {
                return wrappedChildren
            }

            let fallbackText: String
            if case let .object(attributes)? = node.attrs["attributes"],
               case let .string(value)? = attributes["text"] {
                fallbackText = value
            } else {
                fallbackText = "spoiler"
            }

            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: spoilerKind,
                text: fallbackText,
                marks: [.init(name: "spoiler")],
                metadata: [
                    "attrs": .object(node.attrs),
                    "text": .string(fallbackText),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerInlineRenderer(for: badgeKind) { node, _, _ in
            let text: String
            if case let .object(attributes)? = node.attrs["attributes"],
               case let .string(value)? = attributes["text"] {
                text = value
            } else {
                text = node.attrs["text"]?.stringValue ?? "badge"
            }

            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: badgeKind,
                text: text,
                marks: [.init(name: "badge")],
                metadata: [
                    "attrs": .object(node.attrs),
                    "text": .string(text),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerInlineRenderer(for: chipKind) { node, context, reg in
            let renderedChildren = try reg.renderInlineChildren(of: node, context: context)
            if !renderedChildren.isEmpty {
                return renderedChildren.map { span in
                    var updated = span
                    updated.marks.append(.init(name: "chip"))
                    return updated
                }
            }

            let text: String
            if case let .object(attributes)? = node.attrs["attributes"],
               case let .string(value)? = attributes["text"] {
                text = value
            } else {
                text = node.attrs["text"]?.stringValue ?? "chip"
            }

            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: chipKind,
                text: text,
                marks: [.init(name: "chip")],
                metadata: [
                    "attrs": .object(node.attrs),
                    "text": .string(text),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerInlineRenderer(for: citeKind) { node, context, reg in
            let renderedChildren = try reg.renderInlineChildren(of: node, context: context)
            let citeID: String
            if case let .object(attributes)? = node.attrs["attributes"],
               case let .string(value)? = attributes["id"] {
                citeID = value
            } else {
                citeID = "unknown"
            }

            if !renderedChildren.isEmpty {
                return renderedChildren.map { span in
                    var updated = span
                    updated.metadata["citeID"] = .string(citeID)
                    updated.metadata["extensionKind"] = .string(node.kind.rawValue)
                    return updated
                }
            }

            let fallbackText = node.attrs["text"]?.stringValue ?? "cite"
            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: citeKind,
                text: fallbackText,
                marks: [.init(name: "cite")],
                metadata: [
                    "attrs": .object(node.attrs),
                    "citeID": .string(citeID),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        return registry
    }

    private static func makeBehaviorRegistry() -> MarkdownContract.NodeBehaviorRegistry {
        MarkdownContract.NodeBehaviorRegistry(schemas: [
            .init(
                kind: .link,
                stateSlots: [:],
                actionMappings: ["linkTap": "activate"],
                effectSpecs: [],
                stateKeyPolicy: .auto
            ),
            .init(
                kind: .codeBlock,
                stateSlots: ["copyStatus": .string("idle")],
                actionMappings: ["copyTap": "copy"],
                effectSpecs: [
                    .init(triggerAction: "copy", emittedAction: "reset", delayMilliseconds: 5000)
                ],
                stateKeyPolicy: .auto
            ),
            .init(
                kind: .blockQuote,
                stateSlots: ["collapsed": .bool(false)],
                actionMappings: ["collapseTap": "toggle"],
                effectSpecs: [],
                stateKeyPolicy: .nodeID
            ),
            .init(
                kind: panelKind,
                stateSlots: ["collapsed": .bool(false)],
                actionMappings: ["panelToggle": "toggle"],
                effectSpecs: [],
                stateKeyPolicy: .attrBusinessID
            ),
            .init(
                kind: thinkKind,
                stateSlots: ["collapsed": .bool(false)],
                actionMappings: [
                    "activate": "toggle",
                    "thinkToggle": "toggle"
                ],
                effectSpecs: [],
                stateKeyPolicy: .auto
            )
        ])
    }

    @MainActor
    private static let runtimePersistenceAdapter: any MarkdownStatePersistenceAdapter = InMemoryRuntimePersistenceAdapter()
    @MainActor
    private static let runtimeDataBindingAdapter: any MarkdownDataBindingAdapter = DefaultRuntimeDataBindingAdapter()

    private static func uiStateBool(
        for block: MarkdownContract.RenderBlock,
        key: String
    ) -> Bool? {
        guard case let .object(uiState)? = block.metadata["uiState"],
              case let .bool(value)? = uiState[key] else {
            return nil
        }
        return value
    }

    private static func tintThinkBody(
        _ result: MarkdownContract.BlockMappingResult
    ) -> MarkdownContract.BlockMappingResult {
        switch result {
        case var .mergeSegment(segment):
            let tinted = NSMutableAttributedString(attributedString: segment.attributedText)
            if tinted.length > 0 {
                tinted.addAttribute(
                    .foregroundColor,
                    value: UIColor.secondaryLabel.withAlphaComponent(0.85),
                    range: NSRange(location: 0, length: tinted.length)
                )
            }
            segment.attributedText = tinted
            return .mergeSegment(segment)
        case .standalone:
            return result
        }
    }

    private static func makeCiteInline(span: MarkdownContract.InlineSpan) -> NSAttributedString {
        let citeID = span.contractAttrString(for: "id")
            ?? span.contractAttrString(for: "citeID")
            ?? "unknown"
        let baseText = span.text.isEmpty ? "cite" : span.text
        let linkTarget = "xhs-cite://\(citeID.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? citeID)"

        let result = NSMutableAttributedString(
            string: baseText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.systemOrange,
                .xhsBaseForegroundColor: UIColor.systemOrange,
                .link: linkTarget,
                .xhsInteractionNodeID: span.id,
                .xhsInteractionNodeKind: span.kind.rawValue,
                .xhsInteractionStateKey: citeID
            ]
        )

        let attachment = NSTextAttachment()
        attachment.image = makeCiteBadgeImage(color: .systemOrange)
        attachment.bounds = CGRect(x: 0, y: -1, width: 12, height: 12)

        let badge = NSMutableAttributedString(attachment: attachment)
        if badge.length > 0 {
            badge.addAttributes(
                [
                    .link: linkTarget,
                    .xhsInteractionNodeID: span.id,
                    .xhsInteractionNodeKind: span.kind.rawValue,
                    .xhsInteractionStateKey: citeID
                ],
                range: NSRange(location: 0, length: badge.length)
            )
        }

        result.append(NSAttributedString(string: " "))
        result.append(badge)
        return result
    }

    private static func makeCiteBadgeImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(origin: .zero, size: size))

            cg.setFillColor(UIColor.white.cgColor)
            let inner = CGRect(x: 3, y: 3, width: 6, height: 6)
            cg.fillEllipse(in: inner)
        }
    }
}

extension MarkdownContract.Value {
    var stringValue: String? {
        if case let .string(raw) = self {
            return raw
        }
        return nil
    }
}

@MainActor
private final class InMemoryRuntimePersistenceAdapter: MarkdownStatePersistenceAdapter {
    private var snapshotsByDocumentID: [String: MarkdownStateSnapshot] = [:]

    func load(documentID: String) -> MarkdownStateSnapshot? {
        snapshotsByDocumentID[documentID]
    }

    func save(documentID: String, snapshot: MarkdownStateSnapshot) {
        snapshotsByDocumentID[documentID] = snapshot
    }
}

@MainActor
private final class DefaultRuntimeDataBindingAdapter: MarkdownDataBindingAdapter {
    func resolveAssociatedData(
        for context: MarkdownEventNodeContext,
        businessContext: [String : MarkdownContract.Value]
    ) -> [String : MarkdownContract.Value] {
        var associated: [String: MarkdownContract.Value] = [
            "documentID": .string(context.documentID),
            "nodeID": .string(context.nodeID),
            "nodeKind": .string(context.nodeKind.rawValue),
            "stateKey": .string(context.stateKey)
        ]
        if let destination = context.nodeMetadata.metadataString(forKey: "destination") {
            associated["destination"] = .string(destination)
        }
        if let payloadURL = context.payload.valueString(forKey: "url") {
            associated["eventURL"] = .string(payloadURL)
            if let citeFromURL = Self.parseCiteID(from: payloadURL) {
                associated["citeID"] = .string(citeFromURL)
            }
        }
        if let businessID = context.nodeMetadata.metadataString(forKey: "businessID") {
            associated["businessID"] = .string(businessID)
        }
        if case let .object(tracking)? = context.nodeMetadata["tracking"] {
            associated["tracking"] = .object(tracking)
        }
        if let citeID = context.nodeMetadata.metadataString(forKey: "citeID")
            ?? context.nodeMetadata.metadataString(forKey: "id") {
            associated["citeID"] = .string(citeID)
        }
        if !context.payload.isEmpty {
            associated["payload"] = .object(context.payload)
        }
        associated["nodeMetadata"] = .object(context.nodeMetadata)
        if !businessContext.isEmpty {
            associated["businessContext"] = .object(businessContext)
        }
        return associated
    }

    private static func parseCiteID(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              components.scheme == "xhs-cite" else {
            return nil
        }

        if let host = components.host, !host.isEmpty {
            return host.removingPercentEncoding ?? host
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { return nil }
        return path.removingPercentEncoding ?? path
    }
}

private extension Dictionary where Key == String, Value == MarkdownContract.Value {
    func valueString(forKey key: String) -> String? {
        if case let .string(value)? = self[key] {
            return value
        }
        return nil
    }

    func metadataString(forKey key: String) -> String? {
        if case let .string(value)? = self[key] {
            return value
        }
        guard case let .object(attrs)? = self["attrs"] else {
            return nil
        }
        if case let .string(value)? = attrs[key] {
            return value
        }
        if case let .object(attributes)? = attrs["attributes"], case let .string(value)? = attributes[key] {
            return value
        }
        return nil
    }
}


extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
