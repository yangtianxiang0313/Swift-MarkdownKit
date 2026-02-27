//
//  RendererOverrideTests.swift
//  XHSMarkdownKitTests
//
//  Created by 沃顿 on 2026-02-25.
//

import XCTest
@testable import XHSMarkdownKit
import XYMarkdown

final class RendererOverrideTests: XCTestCase {
    
    override func tearDown() {
        // 清理全局注册
        NodeRendererRegistry.shared.removeAll()
        super.tearDown()
    }
    
    func testOverrideHeadingRenderer() {
        // 创建自定义渲染器
        let customRenderer = ClosureAttributedStringRenderer { node, context in
            guard let heading = node as? Heading else {
                return NSAttributedString()
            }
            return NSAttributedString(string: "【自定义】\(heading.plainText)")
        }
        
        // 注册覆盖
        NodeRendererRegistry.shared.register(.heading(level: 1), renderer: customRenderer)
        
        // 渲染
        let markdown = "# 标题"
        let result = MarkdownKit.render(markdown)
        
        XCTAssertTrue(result.attributedString.string.contains("【自定义】"))
    }
    
    func testConfigurationLevelOverride() {
        // 创建配置级别的覆盖
        var config = MarkdownConfiguration.default
        config.override(.paragraph, with: ClosureAttributedStringRenderer { node, context in
            return NSAttributedString(string: "[段落已覆盖]")
        })
        
        let markdown = "这是一段文字"
        let result = MarkdownKit.render(markdown, configuration: config)
        
        XCTAssertTrue(result.attributedString.string.contains("[段落已覆盖]"))
    }
    
    func testOverridePriority() {
        // 全局注册
        NodeRendererRegistry.shared.register(.paragraph) { _, _ in
            NSAttributedString(string: "[全局]")
        }
        
        // 配置级别覆盖（应该优先）
        var config = MarkdownConfiguration.default
        config.override(.paragraph, with: ClosureAttributedStringRenderer { _, _ in
            NSAttributedString(string: "[配置级]")
        })
        
        let markdown = "段落"
        let result = MarkdownKit.render(markdown, configuration: config)
        
        // 配置级别应该优先于全局
        XCTAssertTrue(result.attributedString.string.contains("[配置级]"))
    }
    
    func testUnregisterRenderer() {
        // 注册
        NodeRendererRegistry.shared.register(.heading(level: 1)) { _, _ in
            NSAttributedString(string: "[自定义]")
        }
        
        // 验证注册生效
        var result = MarkdownKit.render("# 标题")
        XCTAssertTrue(result.attributedString.string.contains("[自定义]"))
        
        // 取消注册
        NodeRendererRegistry.shared.unregister(.heading(level: 1))
        
        // 验证恢复默认
        result = MarkdownKit.render("# 标题")
        XCTAssertFalse(result.attributedString.string.contains("[自定义]"))
    }
}
