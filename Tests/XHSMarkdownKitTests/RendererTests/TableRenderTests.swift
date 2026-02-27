import XCTest
@testable import XHSMarkdownKit

/// 表格渲染测试
final class TableRenderTests: XCTestCase {
    
    var theme: MarkdownTheme!
    
    override func setUp() {
        super.setUp()
        theme = .default
    }
    
    override func tearDown() {
        theme = nil
        super.tearDown()
    }
    
    // MARK: - 基础表格测试
    
    func testBasicTable() {
        let markdown = """
        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 表格应该生成 ViewFragment
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        XCTAssertEqual(viewFragments.count, 1, "表格应该生成一个 ViewFragment")
        
        guard let tableFragment = viewFragments.first else {
            XCTFail("未找到表格 Fragment")
            return
        }
        
        XCTAssertTrue(tableFragment.fragmentId.hasPrefix("table"), "表格 Fragment ID 应以 table 开头")
    }
    
    func testTableWithAlignment() {
        let markdown = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | L    | C      | R     |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 验证生成了 ViewFragment
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        XCTAssertEqual(viewFragments.count, 1)
    }
    
    func testTableMultipleRows() {
        let markdown = """
        | Name | Age | City |
        |------|-----|------|
        | Alice | 25 | NYC |
        | Bob | 30 | LA |
        | Charlie | 35 | SF |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        XCTAssertEqual(viewFragments.count, 1)
    }
    
    // MARK: - 表格边界情况
    
    func testEmptyTable() {
        let markdown = """
        | | |
        |-|-|
        | | |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        XCTAssertFalse(result.fragments.isEmpty, "空表格也应该生成 Fragment")
    }
    
    func testSingleColumnTable() {
        let markdown = """
        | Column |
        |--------|
        | Value  |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        XCTAssertEqual(viewFragments.count, 1)
    }
    
    func testTableWithStyledContent() {
        let markdown = """
        | Feature | Status |
        |---------|--------|
        | **Bold** | ✅ |
        | *Italic* | ✅ |
        | `Code` | ✅ |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        XCTAssertEqual(viewFragments.count, 1)
    }
    
    func testTableWithLinks() {
        let markdown = """
        | Name | Link |
        |------|------|
        | Example | [Click](https://example.com) |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        XCTAssertEqual(viewFragments.count, 1)
    }
    
    // MARK: - 表格与其他元素混合
    
    func testTableBetweenParagraphs() {
        let markdown = """
        This is a paragraph before the table.
        
        | A | B |
        |---|---|
        | 1 | 2 |
        
        This is a paragraph after the table.
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 应该有: TextFragment(段落) + ViewFragment(表格) + TextFragment(段落)
        XCTAssertTrue(result.fragments.count >= 3, "应该至少有3个 Fragment")
        
        let textFragments = result.fragments.compactMap { $0 as? TextFragment }
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        
        XCTAssertTrue(textFragments.count >= 2, "应该有至少2个文本 Fragment")
        XCTAssertEqual(viewFragments.count, 1, "应该有1个表格 ViewFragment")
    }
    
    // MARK: - 表格高度计算
    
    func testTableHeightCalculation() {
        let markdown = """
        | A | B | C |
        |---|---|---|
        | 1 | 2 | 3 |
        | 4 | 5 | 6 |
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        guard let tableFragment = result.fragments.compactMap({ $0 as? ViewFragment }).first else {
            XCTFail("未找到表格 Fragment")
            return
        }
        
        let height = tableFragment.estimatedHeight(maxWidth: 320)
        XCTAssertGreaterThan(height, 0, "表格高度应该大于 0")
    }
}
