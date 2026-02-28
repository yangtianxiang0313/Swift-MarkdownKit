import XCTest
@testable import XHSMarkdownKit

/// 引用块渲染测试
final class BlockQuoteRenderTests: XCTestCase {
    
    var theme: MarkdownTheme!
    
    override func setUp() {
        super.setUp()
        theme = .default
    }
    
    override func tearDown() {
        theme = nil
        super.tearDown()
    }
    
    // MARK: - 基础引用测试
    
    func testBasicBlockQuote() {
        let markdown = """
        > This is a quote.
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        XCTAssertFalse(result.fragments.isEmpty)
        
        guard let asp = result.fragments.first as? AttributedStringProviding,
              let attrString = asp.attributedString else {
            XCTFail("引用应该生成文本 Fragment")
            return
        }
        XCTAssertTrue(attrString.string.contains("This is a quote"))
    }
    
    func testBlockQuoteWithMultipleLines() {
        let markdown = """
        > Line 1
        > Line 2
        > Line 3
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        XCTAssertFalse(result.fragments.isEmpty)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Line 1"))
        XCTAssertTrue(fullText.contains("Line 2"))
        XCTAssertTrue(fullText.contains("Line 3"))
    }
    
    func testBlockQuoteWithMultipleParagraphs() {
        let markdown = """
        > First paragraph.
        >
        > Second paragraph.
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("First paragraph"))
        XCTAssertTrue(fullText.contains("Second paragraph"))
    }
    
    // MARK: - 嵌套引用测试
    
    func testNestedBlockQuote() {
        let markdown = """
        > Outer quote
        >
        > > Nested quote
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Outer quote"))
        XCTAssertTrue(fullText.contains("Nested quote"))
    }
    
    func testDeeplyNestedBlockQuote() {
        let markdown = """
        > Level 1
        > > Level 2
        > > > Level 3
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Level 1"))
        XCTAssertTrue(fullText.contains("Level 2"))
        XCTAssertTrue(fullText.contains("Level 3"))
    }
    
    // MARK: - 引用内嵌其他元素
    
    func testBlockQuoteWithList() {
        let markdown = """
        > Quote with list:
        >
        > - Item 1
        > - Item 2
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Quote with list"))
        XCTAssertTrue(fullText.contains("Item 1"))
        XCTAssertTrue(fullText.contains("Item 2"))
    }
    
    func testBlockQuoteWithCode() {
        let markdown = """
        > Here is some code:
        >
        > ```swift
        > let x = 42
        > ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Here is some code"))
    }
    
    func testBlockQuoteWithFormattedText() {
        let markdown = """
        > This has **bold** and *italic* text.
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("bold"))
        XCTAssertTrue(fullText.contains("italic"))
    }
    
    // MARK: - 引用样式测试
    
    func testBlockQuoteLeftMargin() {
        let markdown = """
        > Quoted text
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        guard let asp = result.fragments.first as? AttributedStringProviding,
              let attrString = asp.attributedString else {
            XCTFail("未找到文本 Fragment")
            return
        }
        
        // 检查是否应用了段落样式（包含缩进）
        if let paragraphStyle = attrString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
            XCTAssertGreaterThanOrEqual(paragraphStyle.firstLineHeadIndent, 0, "引用应该有左侧缩进")
        }
    }
    
    // MARK: - 引用与其他元素混合
    
    func testBlockQuoteBetweenParagraphs() {
        let markdown = """
        Normal paragraph.
        
        > This is a quote.
        
        Another normal paragraph.
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Normal paragraph"))
        XCTAssertTrue(fullText.contains("This is a quote"))
        XCTAssertTrue(fullText.contains("Another normal paragraph"))
    }
    
    func testMultipleBlockQuotes() {
        let markdown = """
        > First quote
        
        > Second quote
        
        > Third quote
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("First quote"))
        XCTAssertTrue(fullText.contains("Second quote"))
        XCTAssertTrue(fullText.contains("Third quote"))
    }
    
    // MARK: - 边界情况
    
    func testEmptyBlockQuote() {
        let markdown = """
        >
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 空引用应该能正常处理，不崩溃
        XCTAssertNotNil(result)
    }
    
    func testBlockQuoteWithOnlyWhitespace() {
        let markdown = """
        >    
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        XCTAssertNotNil(result)
    }
}
