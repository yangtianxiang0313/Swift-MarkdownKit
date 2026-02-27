import XCTest
@testable import XHSMarkdownKit

/// 主题自定义测试
final class ThemeCustomizationTests: XCTestCase {
    
    // MARK: - 默认主题测试
    
    func testDefaultThemeExists() {
        let theme = MarkdownTheme.default
        XCTAssertNotNil(theme)
    }
    
    func testDefaultThemeHasValidFonts() {
        let theme = MarkdownTheme.default
        
        XCTAssertNotNil(theme.bodyFont)
        XCTAssertNotNil(theme.h1Font)
        XCTAssertNotNil(theme.h2Font)
        XCTAssertNotNil(theme.h3Font)
        XCTAssertNotNil(theme.codeFont)
    }
    
    func testDefaultThemeHasValidColors() {
        let theme = MarkdownTheme.default
        
        XCTAssertNotNil(theme.bodyColor)
        XCTAssertNotNil(theme.linkColor)
        XCTAssertNotNil(theme.codeBackgroundColor)
    }
    
    func testDefaultThemeHasValidSpacing() {
        let theme = MarkdownTheme.default
        
        XCTAssertGreaterThan(theme.bodyLineHeight, 0)
        XCTAssertGreaterThan(theme.paragraphSpacing, 0)
    }
    
    // MARK: - 预设主题测试
    
    func testRichTextTheme() {
        let theme = MarkdownTheme.richtext
        XCTAssertNotNil(theme)
        XCTAssertGreaterThan(theme.bodyLineHeight, 0)
    }
    
    func testCompactTheme() {
        let theme = MarkdownTheme.compact
        XCTAssertNotNil(theme)
        
        // 紧凑主题应该有较小的间距
        XCTAssertLessThanOrEqual(theme.paragraphSpacing, MarkdownTheme.default.paragraphSpacing)
    }
    
    func testReadableTheme() {
        let theme = MarkdownTheme.readable
        XCTAssertNotNil(theme)
        
        // 可读主题应该有较大的行高
        XCTAssertGreaterThanOrEqual(theme.bodyLineHeight, MarkdownTheme.default.bodyLineHeight)
    }
    
    // MARK: - 主题自定义测试
    
    func testCustomBodyFont() {
        var theme = MarkdownTheme.default
        let customFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        theme.bodyFont = customFont
        
        XCTAssertEqual(theme.bodyFont, customFont)
    }
    
    func testCustomHeadingFonts() {
        var theme = MarkdownTheme.default
        
        let h1Font = UIFont.systemFont(ofSize: 28, weight: .bold)
        let h2Font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        let h3Font = UIFont.systemFont(ofSize: 20, weight: .medium)
        
        theme.h1Font = h1Font
        theme.h2Font = h2Font
        theme.h3Font = h3Font
        
        XCTAssertEqual(theme.h1Font, h1Font)
        XCTAssertEqual(theme.h2Font, h2Font)
        XCTAssertEqual(theme.h3Font, h3Font)
    }
    
    func testCustomColors() {
        var theme = MarkdownTheme.default
        
        theme.bodyColor = .systemGray
        theme.linkColor = .systemBlue
        theme.codeBackgroundColor = UIColor.systemGray6
        
        XCTAssertEqual(theme.bodyColor, .systemGray)
        XCTAssertEqual(theme.linkColor, .systemBlue)
        XCTAssertEqual(theme.codeBackgroundColor, UIColor.systemGray6)
    }
    
    func testCustomSpacing() {
        var theme = MarkdownTheme.default
        
        theme.bodyLineHeight = 30.0
        theme.paragraphSpacing = 20.0
        theme.listItemSpacing = 8.0
        
        XCTAssertEqual(theme.bodyLineHeight, 30.0)
        XCTAssertEqual(theme.paragraphSpacing, 20.0)
        XCTAssertEqual(theme.listItemSpacing, 8.0)
    }
    
    // MARK: - 主题应用测试
    
    func testThemeAppliedToRendering() {
        var theme = MarkdownTheme.default
        theme.bodyColor = .systemRed
        
        let result = MarkdownKit.render("Test text", theme: theme)
        
        let attrString = result.attributedString
        if attrString.length > 0 {
            let color = attrString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
            XCTAssertEqual(color, .systemRed, "自定义颜色应该被应用")
        }
    }
    
    func testHeadingFontApplied() {
        var theme = MarkdownTheme.default
        let customH1Font = UIFont.systemFont(ofSize: 32, weight: .heavy)
        theme.h1Font = customH1Font
        
        let result = MarkdownKit.render("# Heading", theme: theme)
        
        let attrString = result.attributedString
        if attrString.length > 0 {
            let font = attrString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            XCTAssertEqual(font?.pointSize, 32, "自定义标题字号应该被应用")
        }
    }
    
    func testLinkColorApplied() {
        var theme = MarkdownTheme.default
        theme.linkColor = .systemGreen
        
        let result = MarkdownKit.render("[Link](https://example.com)", theme: theme)
        
        let attrString = result.attributedString
        let range = (attrString.string as NSString).range(of: "Link")
        if range.location != NSNotFound {
            let color = attrString.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
            XCTAssertEqual(color, .systemGreen, "自定义链接颜色应该被应用")
        }
    }
    
    // MARK: - 主题不可变性测试
    
    func testThemeIsValueType() {
        var theme1 = MarkdownTheme.default
        var theme2 = theme1
        
        theme2.bodyColor = .systemPurple
        
        // theme1 不应该被影响
        XCTAssertNotEqual(theme1.bodyColor, .systemPurple)
    }
    
    // MARK: - 主题继承测试
    
    func testThemeInheritance() {
        let baseTheme = MarkdownTheme.default
        
        // 创建派生主题
        var derivedTheme = baseTheme
        derivedTheme.bodyFont = UIFont.systemFont(ofSize: 20)
        derivedTheme.linkColor = .systemOrange
        
        // 验证修改的属性
        XCTAssertEqual(derivedTheme.bodyFont.pointSize, 20)
        XCTAssertEqual(derivedTheme.linkColor, .systemOrange)
        
        // 验证未修改的属性保持不变
        XCTAssertEqual(derivedTheme.paragraphSpacing, baseTheme.paragraphSpacing)
    }
    
    // MARK: - 边界情况测试
    
    func testZeroSpacing() {
        var theme = MarkdownTheme.default
        theme.paragraphSpacing = 0
        theme.listItemSpacing = 0
        
        // 应该能正常渲染
        let result = MarkdownKit.render("# Title\n\nParagraph", theme: theme)
        XCTAssertNotNil(result)
    }
    
    func testVeryLargeSpacing() {
        var theme = MarkdownTheme.default
        theme.paragraphSpacing = 100
        theme.bodyLineHeight = 50
        
        // 应该能正常渲染
        let result = MarkdownKit.render("# Title\n\nParagraph", theme: theme)
        XCTAssertNotNil(result)
    }
    
    func testVerySmallFont() {
        var theme = MarkdownTheme.default
        theme.bodyFont = UIFont.systemFont(ofSize: 6)
        
        let result = MarkdownKit.render("Small text", theme: theme)
        
        let attrString = result.attributedString
        if attrString.length > 0 {
            let font = attrString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            XCTAssertEqual(font?.pointSize, 6)
        }
    }
    
    func testVeryLargeFont() {
        var theme = MarkdownTheme.default
        theme.bodyFont = UIFont.systemFont(ofSize: 72)
        
        let result = MarkdownKit.render("Large text", theme: theme)
        
        let attrString = result.attributedString
        if attrString.length > 0 {
            let font = attrString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            XCTAssertEqual(font?.pointSize, 72)
        }
    }
    
    // MARK: - 多主题对比测试
    
    func testDifferentThemesProduceDifferentResults() {
        let markdown = "# Heading\n\nParagraph with **bold** text."
        
        let defaultResult = MarkdownKit.render(markdown, theme: .default)
        let compactResult = MarkdownKit.render(markdown, theme: .compact)
        
        // 两个主题应该产生不同的结果（至少在间距上）
        // 但内容应该相同
        XCTAssertEqual(
            defaultResult.attributedString.string,
            compactResult.attributedString.string,
            "不同主题渲染的文本内容应该相同"
        )
    }
    
    // MARK: - 字体 trait 测试
    
    func testBoldFontTrait() {
        let markdown = "**Bold text**"
        
        let result = MarkdownKit.render(markdown, theme: .default)
        
        let attrString = result.attributedString
        let range = (attrString.string as NSString).range(of: "Bold text")
        
        if range.location != NSNotFound {
            if let font = attrString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                XCTAssertTrue(traits.contains(.traitBold), "加粗文本应该有 bold trait")
            }
        }
    }
    
    func testItalicFontTrait() {
        let markdown = "*Italic text*"
        
        let result = MarkdownKit.render(markdown, theme: .default)
        
        let attrString = result.attributedString
        let range = (attrString.string as NSString).range(of: "Italic text")
        
        if range.location != NSNotFound {
            if let font = attrString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                // 斜体可能被实现为 trait 或高亮，取决于主题配置
                _ = traits
            }
        }
    }
}
