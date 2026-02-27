//
//  ListRenderTests.swift
//  XHSMarkdownKitTests
//
//  Created by 沃顿 on 2026-02-25.
//

import XCTest
@testable import XHSMarkdownKit
import XYMarkdown

final class ListRenderTests: XCTestCase {
    
    func testUnorderedList() {
        let markdown = """
        - 项目一
        - 项目二
        - 项目三
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
        XCTAssertTrue(result.attributedString.string.contains("项目一"))
    }
    
    func testOrderedList() {
        let markdown = """
        1. 第一项
        2. 第二项
        3. 第三项
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
        XCTAssertTrue(result.attributedString.string.contains("第一项"))
    }
    
    func testNestedList() {
        let markdown = """
        - 一级
          - 二级
            - 三级
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
    }
    
    func testMixedList() {
        let markdown = """
        1. 有序项
           - 无序子项
           - 另一个无序子项
        2. 第二个有序项
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
    }
    
    func testListWithParagraphs() {
        let markdown = """
        - 项目一
        
          这是项目一的段落
        
        - 项目二
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
    }
    
    func testOrderedListStartIndex() {
        let markdown = """
        5. 从五开始
        6. 第六项
        """
        let result = MarkdownKit.render(markdown)
        
        XCTAssertFalse(result.fragments.isEmpty)
    }
}
