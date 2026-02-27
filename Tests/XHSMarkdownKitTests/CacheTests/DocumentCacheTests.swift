//
//  DocumentCacheTests.swift
//  XHSMarkdownKitTests
//
//  Created by 沃顿 on 2026-02-25.
//

import XCTest
@testable import XHSMarkdownKit
import XYMarkdown

final class DocumentCacheTests: XCTestCase {
    
    var cache: DocumentCache!
    
    override func setUp() {
        super.setUp()
        cache = DocumentCache(countLimit: 10)
    }
    
    override func tearDown() {
        cache.removeAll()
        cache = nil
        super.tearDown()
    }
    
    func testCacheHit() {
        let markdown = "# 标题"
        
        // 首次解析
        let doc1 = cache.document(for: markdown)
        
        // 二次获取（应该命中缓存）
        let doc2 = cache.document(for: markdown)
        
        XCTAssertTrue(cache.contains(markdown))
    }
    
    func testCacheMiss() {
        let markdown1 = "# 标题一"
        let markdown2 = "# 标题二"
        
        _ = cache.document(for: markdown1)
        
        XCTAssertTrue(cache.contains(markdown1))
        XCTAssertFalse(cache.contains(markdown2))
    }
    
    func testCacheClear() {
        let markdown = "# 标题"
        
        _ = cache.document(for: markdown)
        XCTAssertTrue(cache.contains(markdown))
        
        cache.removeAll()
        XCTAssertFalse(cache.contains(markdown))
    }
    
    func testDifferentMarkdownsDifferentDocuments() {
        let markdown1 = "# 标题一"
        let markdown2 = "## 标题二"
        
        let doc1 = cache.document(for: markdown1)
        let doc2 = cache.document(for: markdown2)
        
        XCTAssertTrue(cache.contains(markdown1))
        XCTAssertTrue(cache.contains(markdown2))
    }
    
    func testSharedCache() {
        let markdown = "# 共享缓存测试"
        
        // 使用共享缓存
        _ = DocumentCache.shared.document(for: markdown)
        XCTAssertTrue(DocumentCache.shared.contains(markdown))
        
        // 清理
        DocumentCache.shared.removeAll()
    }
}
