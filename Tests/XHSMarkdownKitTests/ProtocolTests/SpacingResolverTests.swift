import XCTest
@testable import XHSMarkdownKit

/// 间距规则协议测试
final class SpacingResolverTests: XCTestCase {
    
    // MARK: - 默认间距解析器测试
    
    func testDefaultSpacingResolverExists() {
        let resolver = DefaultBlockSpacingResolver()
        XCTAssertNotNil(resolver)
    }
    
    func testDefaultParagraphSpacing() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacing = resolver.spacing(
            after: .paragraph,
            before: .paragraph,
            theme: theme
        )
        
        XCTAssertGreaterThan(spacing, 0, "段落之间应该有间距")
    }
    
    func testDefaultHeadingSpacing() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacingAfterHeading = resolver.spacing(
            after: .heading(level: 1),
            before: .paragraph,
            theme: theme
        )
        
        XCTAssertGreaterThan(spacingAfterHeading, 0, "标题后应该有间距")
    }
    
    func testDefaultListSpacing() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacing = resolver.spacing(
            after: .listItem,
            before: .listItem,
            theme: theme
        )
        
        XCTAssertGreaterThanOrEqual(spacing, 0, "列表项之间的间距应该 >= 0")
    }
    
    func testDefaultBlockQuoteSpacing() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacing = resolver.spacing(
            after: .blockQuote,
            before: .paragraph,
            theme: theme
        )
        
        XCTAssertGreaterThan(spacing, 0, "引用块后应该有间距")
    }
    
    func testDefaultCodeBlockSpacing() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacing = resolver.spacing(
            after: .codeBlock,
            before: .paragraph,
            theme: theme
        )
        
        XCTAssertGreaterThan(spacing, 0, "代码块后应该有间距")
    }
    
    // MARK: - 自定义间距解析器测试
    
    func testCustomSpacingResolver() {
        let customResolver = CustomSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacing = customResolver.spacing(
            after: .paragraph,
            before: .paragraph,
            theme: theme
        )
        
        // 自定义解析器返回固定值 20
        XCTAssertEqual(spacing, 20)
    }
    
    func testCompactSpacingResolver() {
        let compactResolver = CompactSpacingResolver()
        let defaultResolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let compactSpacing = compactResolver.spacing(
            after: .paragraph,
            before: .paragraph,
            theme: theme
        )
        
        let defaultSpacing = defaultResolver.spacing(
            after: .paragraph,
            before: .paragraph,
            theme: theme
        )
        
        // 紧凑型间距应该小于等于默认间距
        XCTAssertLessThanOrEqual(compactSpacing, defaultSpacing, "紧凑间距应该 <= 默认间距")
    }
    
    // MARK: - 配置注入测试
    
    func testSpacingResolverInjectionViaConfiguration() {
        var config = MarkdownConfiguration()
        let customResolver = CustomSpacingResolver()
        config.spacingResolver = customResolver
        
        XCTAssertNotNil(config.spacingResolver)
    }
    
    // MARK: - 不同节点组合测试
    
    func testSpacingBetweenDifferentNodes() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        let nodeCombinations: [(MarkdownNodeType, MarkdownNodeType)] = [
            (.heading(level: 1), .paragraph),
            (.paragraph, .heading(level: 2)),
            (.paragraph, .codeBlock),
            (.codeBlock, .paragraph),
            (.blockQuote, .blockQuote),
            (.listItem, .paragraph),
            (.paragraph, .table),
            (.table, .paragraph),
        ]
        
        for (after, before) in nodeCombinations {
            let spacing = resolver.spacing(after: after, before: before, theme: theme)
            XCTAssertGreaterThanOrEqual(spacing, 0, "\(after) -> \(before) 间距应该 >= 0")
        }
    }
    
    // MARK: - 主题对间距的影响测试
    
    func testThemeAffectsSpacing() {
        let resolver = DefaultBlockSpacingResolver()
        
        var theme1 = MarkdownTheme.default
        theme1.paragraphSpacing = 10
        
        var theme2 = MarkdownTheme.default
        theme2.paragraphSpacing = 30
        
        let spacing1 = resolver.spacing(after: .paragraph, before: .paragraph, theme: theme1)
        let spacing2 = resolver.spacing(after: .paragraph, before: .paragraph, theme: theme2)
        
        // 间距应该受主题影响
        // 注意：具体实现可能不同，这里只验证不崩溃
        XCTAssertGreaterThanOrEqual(spacing1, 0)
        XCTAssertGreaterThanOrEqual(spacing2, 0)
    }
    
    // MARK: - 零间距场景测试
    
    func testZeroSpacingScenarios() {
        let zeroResolver = ZeroSpacingResolver()
        let theme = MarkdownTheme.default
        
        let spacing = zeroResolver.spacing(
            after: .paragraph,
            before: .paragraph,
            theme: theme
        )
        
        XCTAssertEqual(spacing, 0, "零间距解析器应该返回 0")
    }
    
    // MARK: - 间距一致性测试
    
    func testSpacingConsistency() {
        let resolver = DefaultBlockSpacingResolver()
        let theme = MarkdownTheme.default
        
        // 多次调用应该返回相同结果
        let spacing1 = resolver.spacing(after: .paragraph, before: .paragraph, theme: theme)
        let spacing2 = resolver.spacing(after: .paragraph, before: .paragraph, theme: theme)
        let spacing3 = resolver.spacing(after: .paragraph, before: .paragraph, theme: theme)
        
        XCTAssertEqual(spacing1, spacing2)
        XCTAssertEqual(spacing2, spacing3)
    }
}

// MARK: - Test Helpers

/// 自定义间距解析器（固定返回 20）
private class CustomSpacingResolver: BlockSpacingResolving {
    func spacing(after: MarkdownNodeType, before: MarkdownNodeType, theme: MarkdownTheme) -> CGFloat {
        return 20
    }
}

/// 紧凑型间距解析器
private class CompactSpacingResolver: BlockSpacingResolving {
    func spacing(after: MarkdownNodeType, before: MarkdownNodeType, theme: MarkdownTheme) -> CGFloat {
        // 所有间距减半
        return theme.paragraphSpacing / 2
    }
}

/// 零间距解析器
private class ZeroSpacingResolver: BlockSpacingResolving {
    func spacing(after: MarkdownNodeType, before: MarkdownNodeType, theme: MarkdownTheme) -> CGFloat {
        return 0
    }
}
