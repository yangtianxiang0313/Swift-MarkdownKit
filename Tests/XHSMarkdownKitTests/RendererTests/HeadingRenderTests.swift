//
//  HeadingRenderTests.swift
//  XHSMarkdownKitTests
//
//  Created by 沃顿 on 2026-02-25.
//

import XCTest
@testable import XHSMarkdownKit
import XYMarkdown

final class HeadingRenderTests: XCTestCase {
    
    func testHeading1Render() {
        let markdown = "# 标题一"
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
        XCTAssertEqual(result.attributedString.string, "标题一")
    }
    
    func testHeading2Render() {
        let markdown = "## 标题二"
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
        XCTAssertEqual(result.attributedString.string, "标题二")
    }
    
    func testHeadingWithInlineStyles() {
        let markdown = "# **加粗**标题"
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
        XCTAssertTrue(result.attributedString.string.contains("加粗"))
    }
    
    func testMultipleHeadings() {
        let markdown = """
        # 标题一
        ## 标题二
        ### 标题三
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertGreaterThan(result.fragments.count, 0)
    }
    
    func testHeadingCustomTheme() {
        var theme = MarkdownTheme()
        theme.headingFonts = [24, 20, 18, 16, 14, 12]
        theme.heading1Color = .red
        
        let markdown = "# 红色标题"
        let result = MarkdownKit.render(markdown, theme: theme)
        
        XCTAssertFalse(result.fragments.isEmpty)
    }
}
