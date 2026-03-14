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
    static func makeConfiguredContainer(theme: MarkdownTheme = .default) -> MarkdownContainerView {
        let container = MarkdownContainerView(theme: theme)
        _ = installMarkdownn(into: container)
        return container
    }

    @discardableResult
    static func installMarkdownn(into container: MarkdownContainerView) -> Bool {
        #if canImport(XYMarkdown)
        let registry = MarkdownContract.AdapterRegistry(
            defaultParserID: MarkdownnAdapter.parserID,
            defaultRendererID: MarkdownnAdapter.rendererID
        )
        MarkdownnAdapter.install(into: registry)
        container.contractKit = MarkdownContract.UniversalMarkdownKit(registry: registry)
        container.contractStreamingEngine = MarkdownnAdapter.makeEngine()
        return true
        #else
        // Root pod (UIKit default) has no parser plugin; keep predictable "parser missing" behavior.
        container.contractKit = MarkdownContract.UniversalMarkdownKit()
        container.contractStreamingEngine = nil
        return false
        #endif
    }
}
