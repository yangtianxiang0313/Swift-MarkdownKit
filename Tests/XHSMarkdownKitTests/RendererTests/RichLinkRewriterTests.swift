import XCTest
@testable import XHSMarkdownKit

/// 富链接 Rewriter 测试
final class RichLinkRewriterTests: XCTestCase {
    
    var theme: MarkdownTheme!
    
    override func setUp() {
        super.setUp()
        theme = .default
    }
    
    override func tearDown() {
        theme = nil
        super.tearDown()
    }
    
    // MARK: - 基础链接测试
    
    func testBasicLink() {
        let markdown = "[Example](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Example"))
        
        // 检查链接属性
        let attrString = result.attributedString
        let range = (attrString.string as NSString).range(of: "Example")
        if range.location != NSNotFound {
            let linkAttr = attrString.attribute(.link, at: range.location, effectiveRange: nil)
            XCTAssertNotNil(linkAttr, "链接文本应该有 .link 属性")
        }
    }
    
    func testLinkWithTitle() {
        let markdown = "[Example](https://example.com \"Title\")"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Example"))
    }
    
    func testAutoLink() {
        let markdown = "<https://example.com>"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("example.com") || fullText.contains("https://"))
    }
    
    // MARK: - 富链接改写测试
    
    func testRichLinkRewriterRegistration() {
        // 创建 RichLinkRewriter
        let rewriter = RichLinkRewriter()
        
        // 注册测试用的富链接模型
        rewriter.register(pattern: "xhslink://") { url in
            // 返回测试模型
            return TestRichLinkModel(displayText: "富链接", linkURL: url, httpLink: nil)
        }
        
        // 验证 rewriter 被创建
        XCTAssertNotNil(rewriter)
    }
    
    func testRewriterPipeline() {
        // 创建 pipeline
        let pipeline = RewriterPipeline()
        let rewriter = RichLinkRewriter()
        pipeline.add(rewriter)
        
        XCTAssertFalse(pipeline.isEmpty)
    }
    
    // MARK: - 链接样式测试
    
    func testLinkColor() {
        let markdown = "[Colored Link](https://example.com)"
        
        var customTheme = MarkdownTheme.default
        customTheme.linkColor = .systemBlue
        
        let result = MarkdownKit.render(markdown, theme: customTheme)
        
        let attrString = result.attributedString
        let range = (attrString.string as NSString).range(of: "Colored Link")
        
        if range.location != NSNotFound {
            let color = attrString.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
            // 链接应该有颜色属性
            XCTAssertNotNil(color, "链接应该有前景色")
        }
    }
    
    func testLinkUnderline() {
        let markdown = "[Underlined Link](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let attrString = result.attributedString
        let range = (attrString.string as NSString).range(of: "Underlined Link")
        
        if range.location != NSNotFound {
            // 检查下划线属性（如果主题启用了下划线）
            let underlineStyle = attrString.attribute(.underlineStyle, at: range.location, effectiveRange: nil)
            // 下划线是可选的，只验证不崩溃
            _ = underlineStyle
        }
    }
    
    // MARK: - 多链接测试
    
    func testMultipleLinks() {
        let markdown = "Visit [Google](https://google.com) or [Apple](https://apple.com)."
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Google"))
        XCTAssertTrue(fullText.contains("Apple"))
    }
    
    func testLinksInDifferentParagraphs() {
        let markdown = """
        First [link1](https://example.com/1).
        
        Second [link2](https://example.com/2).
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("link1"))
        XCTAssertTrue(fullText.contains("link2"))
    }
    
    // MARK: - 链接嵌套测试
    
    func testLinkWithBoldText() {
        let markdown = "[**Bold Link**](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Bold Link"))
    }
    
    func testLinkWithInlineCode() {
        let markdown = "[`code link`](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("code link"))
    }
    
    // MARK: - 边界情况
    
    func testEmptyLinkText() {
        let markdown = "[](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 空链接文本应该能处理
        XCTAssertNotNil(result)
    }
    
    func testLinkWithSpecialCharacters() {
        let markdown = "[Link with spaces & symbols!](https://example.com/path?query=value&foo=bar)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Link with spaces"))
    }
    
    func testLinkWithBrackets() {
        let markdown = "[Link [with] brackets](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 应该能处理，不崩溃
        XCTAssertNotNil(result)
    }
    
    // MARK: - 链接在不同上下文中
    
    func testLinkInList() {
        let markdown = """
        - [Item 1](https://example.com/1)
        - [Item 2](https://example.com/2)
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Item 1"))
        XCTAssertTrue(fullText.contains("Item 2"))
    }
    
    func testLinkInBlockQuote() {
        let markdown = """
        > Check out [this link](https://example.com).
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("this link"))
    }
    
    func testLinkInHeading() {
        let markdown = "# [Heading Link](https://example.com)"
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Heading Link"))
    }
}

// MARK: - Test Helpers

/// 测试用富链接模型
private struct TestRichLinkModel: RichLinkModel {
    let displayText: String
    let linkURL: String
    let httpLink: String?
}
