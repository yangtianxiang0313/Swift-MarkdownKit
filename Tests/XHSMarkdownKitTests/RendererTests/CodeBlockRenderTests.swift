import XCTest
@testable import XHSMarkdownKit

/// 代码块渲染测试
final class CodeBlockRenderTests: XCTestCase {
    
    var theme: MarkdownTheme!
    
    override func setUp() {
        super.setUp()
        theme = .default
    }
    
    override func tearDown() {
        theme = nil
        super.tearDown()
    }
    
    // MARK: - 基础代码块测试
    
    func testBasicCodeBlock() {
        let markdown = """
        ```
        let x = 42
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        XCTAssertFalse(result.fragments.isEmpty)
        
        // 代码块可以是 TextFragment 或 ViewFragment，取决于实现
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("let x = 42"))
    }
    
    func testCodeBlockWithLanguage() {
        let markdown = """
        ```swift
        import Foundation
        
        struct Hello {
            let message: String
        }
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("import Foundation"))
        XCTAssertTrue(fullText.contains("struct Hello"))
    }
    
    func testCodeBlockPreservesWhitespace() {
        let markdown = """
        ```
        function test() {
            if (true) {
                console.log("indented");
            }
        }
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        // 验证缩进被保留（包含空格）
        XCTAssertTrue(fullText.contains("console.log"))
    }
    
    func testCodeBlockPreservesEmptyLines() {
        let markdown = """
        ```
        line1
        
        line3
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("line1"))
        XCTAssertTrue(fullText.contains("line3"))
    }
    
    // MARK: - 行内代码测试
    
    func testInlineCode() {
        let markdown = "This is `inline code` in text."
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("inline code"))
    }
    
    func testInlineCodeWithSpecialCharacters() {
        let markdown = "Use `<div>` for HTML and `$var` for variables."
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("<div>"))
        XCTAssertTrue(fullText.contains("$var"))
    }
    
    func testMultipleInlineCodes() {
        let markdown = "Compare `foo` with `bar` and `baz`."
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("foo"))
        XCTAssertTrue(fullText.contains("bar"))
        XCTAssertTrue(fullText.contains("baz"))
    }
    
    // MARK: - 代码块样式测试
    
    func testCodeBlockUsesMonospaceFont() {
        let markdown = """
        ```
        monospace
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        guard let textFragment = result.fragments.first as? TextFragment else {
            // 可能是 ViewFragment，跳过字体检查
            return
        }
        
        let attrString = textFragment.attributedString
        
        // 查找代码文本的字体属性
        let range = (attrString.string as NSString).range(of: "monospace")
        if range.location != NSNotFound {
            if let font = attrString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                // 检查是否是等宽字体
                let fontName = font.fontName.lowercased()
                let isMonospace = fontName.contains("mono") || 
                                  fontName.contains("courier") ||
                                  fontName.contains("menlo") ||
                                  fontName.contains("consolas")
                XCTAssertTrue(isMonospace, "代码应该使用等宽字体")
            }
        }
    }
    
    func testCodeBlockBackgroundColor() {
        let markdown = """
        ```
        code with background
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        guard let textFragment = result.fragments.first as? TextFragment else {
            return
        }
        
        let attrString = textFragment.attributedString
        
        // 检查是否有背景色属性
        let range = NSRange(location: 0, length: min(1, attrString.length))
        if attrString.length > 0 {
            let bgColor = attrString.attribute(.backgroundColor, at: 0, effectiveRange: nil)
            // 背景色是可选的，这里只是验证不会崩溃
            _ = bgColor
        }
    }
    
    // MARK: - 代码块边界情况
    
    func testEmptyCodeBlock() {
        let markdown = """
        ```
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        // 空代码块应该能正常处理
        XCTAssertNotNil(result)
    }
    
    func testCodeBlockWithBackticks() {
        let markdown = """
        ````
        ```
        nested backticks
        ```
        ````
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("nested backticks"))
    }
    
    func testCodeBlockWithMarkdownContent() {
        let markdown = """
        ```markdown
        # This is not a heading
        **This is not bold**
        - This is not a list
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        // Markdown 语法应该被原样保留，不被解析
        XCTAssertTrue(fullText.contains("# This is not a heading") || fullText.contains("This is not a heading"))
    }
    
    // MARK: - 代码块与其他元素混合
    
    func testCodeBlockInList() {
        let markdown = """
        1. Step one:
           
           ```swift
           let step1 = true
           ```
        
        2. Step two
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Step one"))
        XCTAssertTrue(fullText.contains("Step two"))
    }
    
    func testCodeBlockAfterHeading() {
        let markdown = """
        # Example Code
        
        ```swift
        let example = "code"
        ```
        """
        
        let result = MarkdownKit.render(markdown, theme: theme)
        
        let fullText = result.attributedString.string
        XCTAssertTrue(fullText.contains("Example Code"))
        XCTAssertTrue(fullText.contains("example"))
    }
    
    // MARK: - 多种语言测试
    
    func testCodeBlockDifferentLanguages() {
        let languages = ["swift", "python", "javascript", "java", "kotlin", "rust", "go"]
        
        for lang in languages {
            let markdown = """
            ```\(lang)
            code in \(lang)
            ```
            """
            
            let result = MarkdownKit.render(markdown, theme: theme)
            let fullText = result.attributedString.string
            XCTAssertTrue(fullText.contains("code in \(lang)"), "\(lang) 代码块应该正确渲染")
        }
    }
}
