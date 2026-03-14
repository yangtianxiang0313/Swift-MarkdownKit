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
            title: "流式",
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
    static let cardKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "card"))
    static let spotlightKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "spotlight"))
    static let badgeKind: MarkdownContract.NodeKind = .ext(.init(namespace: "example", name: "badge"))

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
            kind: cardKind,
            role: .blockContainer,
            childPolicy: .blockOnly(minChildren: 0),
            parseAliases: [.init(sourceKind: .directive, name: "Card")]
        ))
        registry.register(.init(
            kind: spotlightKind,
            role: .blockContainer,
            childPolicy: .blockOnly(minChildren: 0),
            parseAliases: [.init(sourceKind: .htmlTag, name: "spotlight")]
        ))
        registry.register(.init(
            kind: badgeKind,
            role: .inlineLeaf,
            childPolicy: .none,
            parseAliases: [.init(sourceKind: .htmlTag, name: "badge")]
        ))

        return registry
    }

    private static func makeCanonicalRendererRegistry() -> MarkdownContract.CanonicalRendererRegistry {
        let registry = MarkdownContract.CanonicalRendererRegistry.makeDefault()

        registry.registerBlockRenderer(for: cardKind) { node, context, reg in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: cardKind,
                children: try reg.renderBlockChildren(of: node, context: context),
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerBlockRenderer(for: spotlightKind) { node, context, reg in
            [MarkdownContract.RenderBlock(
                id: node.id,
                kind: spotlightKind,
                children: try reg.renderBlockChildren(of: node, context: context),
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        registry.registerInlineRenderer(for: badgeKind) { node, _, _ in
            let text: String
            if case let .object(attributes)? = node.attrs["attributes"],
               case let .string(raw)? = attributes["text"] {
                text = raw
            } else {
                text = "badge"
            }

            return [MarkdownContract.InlineSpan(
                id: node.id,
                kind: badgeKind,
                text: text,
                metadata: [
                    "attrs": .object(node.attrs),
                    "extensionKind": .string(node.kind.rawValue)
                ]
            )]
        }

        return registry
    }
}
