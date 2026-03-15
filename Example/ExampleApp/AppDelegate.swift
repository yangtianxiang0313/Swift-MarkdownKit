import UIKit
import XHSMarkdownKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
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
        
        return true
    }
}

enum ExampleMarkdownRuntime {
    static let calloutKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "callout"))
    static let tabsKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "tabs"))
    static let mentionKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "mention"))
    static let spoilerKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "spoiler"))

    static func makeConfiguredContainer(theme: MarkdownTheme = .default) -> MarkdownContainerView {
        let container = MarkdownContainerView(theme: theme)
        _ = installMarkdownn(into: container)
        return container
    }

    static func makeRewritePipeline() -> MarkdownContract.CanonicalRewritePipeline {
        MarkdownContract.CanonicalRewritePipeline(nodeSpecRegistry: makeNodeSpecRegistry())
    }

    @discardableResult
    static func installMarkdownn(into container: MarkdownContainerView) -> Bool {
        #if canImport(XYMarkdown)
        let nodeSpecs = makeNodeSpecRegistry()
        let canonicalRegistry = makeCanonicalRendererRegistry()
        let rewritePipeline = MarkdownContract.CanonicalRewritePipeline(nodeSpecRegistry: nodeSpecs)

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
        container.contractStreamingEngine = MarkdownnAdapter.makeEngine(
            rewritePipeline: rewritePipeline,
            nodeSpecRegistry: nodeSpecs,
            canonicalRendererRegistry: canonicalRegistry
        )
        return true
        #else
        // Root pod (UIKit default) has no parser plugin; keep predictable "parser missing" behavior.
        container.contractKit = MarkdownContract.UniversalMarkdownKit()
        container.contractStreamingEngine = nil
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

        return registry
    }
}

private extension MarkdownContract.Value {
    var stringValue: String? {
        if case let .string(raw) = self {
            return raw
        }
        return nil
    }
}
