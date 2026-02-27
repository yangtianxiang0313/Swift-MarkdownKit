import XCTest
@testable import XHSMarkdownKit
import XYMarkdown

/// 自定义节点注册测试
final class CustomNodeRegistrationTests: XCTestCase {
    
    var registry: NodeRendererRegistry!
    
    override func setUp() {
        super.setUp()
        registry = NodeRendererRegistry()
    }
    
    override func tearDown() {
        registry = nil
        super.tearDown()
    }
    
    // MARK: - 自定义 AttributedString 渲染器注册
    
    func testRegisterCustomAttributedStringRenderer() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册自定义段落渲染器
        let customRenderer = CustomParagraphRenderer()
        customRegistry.register(.paragraph, renderer: customRenderer)
        
        // 验证注册成功
        let retrieved = customRegistry.renderer(for: .paragraph)
        XCTAssertNotNil(retrieved, "应该能获取到注册的渲染器")
    }
    
    func testRegisterMultipleRenderers() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册多个不同类型的渲染器
        customRegistry.register(.paragraph, renderer: CustomParagraphRenderer())
        customRegistry.register(.heading(level: 1), renderer: CustomHeadingRenderer())
        
        // 验证都能获取到
        XCTAssertNotNil(customRegistry.renderer(for: .paragraph))
        XCTAssertNotNil(customRegistry.renderer(for: .heading(level: 1)))
    }
    
    // MARK: - 自定义 View 渲染器注册
    
    func testRegisterCustomViewRenderer() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册自定义表格视图渲染器
        let customRenderer = CustomTableViewRenderer()
        customRegistry.register(.table, viewRenderer: customRenderer)
        
        // 验证注册成功
        let retrieved = customRegistry.renderer(for: .table)
        XCTAssertNotNil(retrieved, "应该能获取到注册的 View 渲染器")
    }
    
    // MARK: - CustomBlock/CustomInline 注册
    
    func testRegisterCustomBlock() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册自定义块节点
        let customRenderer = CustomBlockRenderer()
        customRegistry.register(.customBlock(identifier: "card"), viewRenderer: customRenderer)
        
        // 验证注册成功
        let retrieved = customRegistry.renderer(for: .customBlock(identifier: "card"))
        XCTAssertNotNil(retrieved)
    }
    
    func testRegisterCustomInline() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册自定义行内节点
        let customRenderer = CustomInlineRenderer()
        customRegistry.register(.customInline(identifier: "mention"), renderer: customRenderer)
        
        // 验证注册成功
        let retrieved = customRegistry.renderer(for: .customInline(identifier: "mention"))
        XCTAssertNotNil(retrieved)
    }
    
    // MARK: - 渲染器覆盖测试
    
    func testRendererOverride() {
        let customRegistry = NodeRendererRegistry()
        
        // 首次注册
        let firstRenderer = CustomParagraphRenderer()
        customRegistry.register(.paragraph, renderer: firstRenderer)
        
        // 第二次注册（覆盖）
        let secondRenderer = AnotherCustomParagraphRenderer()
        customRegistry.register(.paragraph, renderer: secondRenderer)
        
        // 应该返回渲染器（被覆盖）
        let retrieved = customRegistry.renderer(for: .paragraph)
        XCTAssertNotNil(retrieved)
    }
    
    // MARK: - 三层查找优先级测试
    
    func testThreeTierLookupPriority() {
        // 创建两个独立的注册表
        let globalRegistry = NodeRendererRegistry()
        let localRegistry = NodeRendererRegistry()
        
        // 全局注册
        globalRegistry.register(.paragraph, renderer: CustomParagraphRenderer())
        
        // 本地注册（应该独立）
        localRegistry.register(.paragraph, renderer: AnotherCustomParagraphRenderer())
        
        // 验证各自独立
        XCTAssertNotNil(globalRegistry.renderer(for: .paragraph))
        XCTAssertNotNil(localRegistry.renderer(for: .paragraph))
    }
    
    // MARK: - 闭包便捷注册
    
    func testClosureRegistration() {
        let customRegistry = NodeRendererRegistry()
        
        // 使用闭包注册
        customRegistry.register(.paragraph) { node, context in
            let attrString = NSMutableAttributedString(string: "Custom Rendered")
            return attrString
        }
        
        // 验证能获取到渲染器
        let renderer = customRegistry.renderer(for: .paragraph)
        XCTAssertNotNil(renderer)
    }
    
    // MARK: - 节点类型匹配测试
    
    func testNodeTypeMatching() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册 heading level 1
        customRegistry.register(.heading(level: 1), renderer: CustomHeadingRenderer())
        
        // heading level 1 应该能获取到
        XCTAssertNotNil(customRegistry.renderer(for: .heading(level: 1)))
        
        // heading level 2 不应该获取到
        XCTAssertNil(customRegistry.renderer(for: .heading(level: 2)))
    }
    
    // MARK: - 批量注册测试
    
    func testBatchRegistration() {
        let customRegistry = NodeRendererRegistry()
        
        // 批量注册多种节点类型
        let nodeTypes: [MarkdownNodeType] = [
            .paragraph,
            .heading(level: 1),
            .heading(level: 2),
            .blockQuote,
            .codeBlock
        ]
        
        for nodeType in nodeTypes {
            customRegistry.register(nodeType, renderer: CustomParagraphRenderer())
        }
        
        // 验证所有都注册成功
        for nodeType in nodeTypes {
            XCTAssertTrue(customRegistry.hasRenderer(for: nodeType), "\(nodeType) 应该有注册的渲染器")
        }
    }
    
    // MARK: - 未注册节点类型测试
    
    func testUnregisteredNodeType() {
        let customRegistry = NodeRendererRegistry()
        
        // 不注册任何渲染器，直接查询
        let renderer = customRegistry.renderer(for: .thematicBreak)
        
        // 应该返回 nil
        XCTAssertNil(renderer)
    }
    
    // MARK: - 移除渲染器测试
    
    func testUnregisterRenderer() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册
        customRegistry.register(.paragraph, renderer: CustomParagraphRenderer())
        XCTAssertNotNil(customRegistry.renderer(for: .paragraph))
        
        // 移除
        customRegistry.unregister(.paragraph)
        XCTAssertNil(customRegistry.renderer(for: .paragraph))
    }
    
    func testRemoveAllRenderers() {
        let customRegistry = NodeRendererRegistry()
        
        // 注册多个
        customRegistry.register(.paragraph, renderer: CustomParagraphRenderer())
        customRegistry.register(.heading(level: 1), renderer: CustomHeadingRenderer())
        
        // 移除全部
        customRegistry.removeAll()
        
        XCTAssertNil(customRegistry.renderer(for: .paragraph))
        XCTAssertNil(customRegistry.renderer(for: .heading(level: 1)))
    }
}

// MARK: - Test Helpers

/// 测试用自定义段落渲染器
private class CustomParagraphRenderer: AttributedStringNodeRenderer {
    func render(node: Markup, context: NodeRenderContext) -> NSAttributedString {
        return NSAttributedString(string: "Custom Paragraph")
    }
}

/// 另一个测试用自定义段落渲染器
private class AnotherCustomParagraphRenderer: AttributedStringNodeRenderer {
    func render(node: Markup, context: NodeRenderContext) -> NSAttributedString {
        return NSAttributedString(string: "Another Custom Paragraph")
    }
}

/// 测试用自定义标题渲染器
private class CustomHeadingRenderer: AttributedStringNodeRenderer {
    func render(node: Markup, context: NodeRenderContext) -> NSAttributedString {
        return NSAttributedString(string: "Custom Heading")
    }
}

/// 测试用自定义表格视图渲染器
private class CustomTableViewRenderer: ViewNodeRenderer {
    var reuseIdentifier: String { "CustomTable" }
    
    func makeView(node: Markup, context: NodeRenderContext) -> UIView {
        return UIView()
    }
    
    func configure(view: UIView, node: Markup, context: NodeRenderContext) {
        view.backgroundColor = .lightGray
    }
    
    func estimatedSize(node: Markup, context: NodeRenderContext) -> CGSize {
        return CGSize(width: context.maxWidth, height: 100)
    }
}

/// 测试用自定义块渲染器
private class CustomBlockRenderer: ViewNodeRenderer {
    var reuseIdentifier: String { "CustomBlock" }
    
    func makeView(node: Markup, context: NodeRenderContext) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }
    
    func configure(view: UIView, node: Markup, context: NodeRenderContext) {}
    
    func estimatedSize(node: Markup, context: NodeRenderContext) -> CGSize {
        return CGSize(width: context.maxWidth, height: 80)
    }
}

/// 测试用自定义行内渲染器
private class CustomInlineRenderer: AttributedStringNodeRenderer {
    func render(node: Markup, context: NodeRenderContext) -> NSAttributedString {
        return NSAttributedString(string: "@mention", attributes: [
            .foregroundColor: UIColor.systemBlue
        ])
    }
}
