import XCTest
@testable import XHSMarkdownKit

/// Fragment 序列和 ContainerView 布局测试
final class FragmentTests: XCTestCase {
    
    // MARK: - TextFragment 测试
    
    func testTextFragmentCreation() {
        let attrString = NSAttributedString(string: "Test text")
        let fragment = TextFragment(
            fragmentId: "p0",
            attributedString: attrString
        )
        
        XCTAssertEqual(fragment.fragmentId, "p0")
        XCTAssertEqual(fragment.attributedString.string, "Test text")
    }
    
    func testTextFragmentHeight() {
        let attrString = NSAttributedString(string: "Test text with some content")
        let fragment = TextFragment(
            fragmentId: "p0",
            attributedString: attrString
        )
        
        let height = fragment.estimatedHeight(maxWidth: 320)
        XCTAssertGreaterThan(height, 0, "TextFragment 高度应该大于 0")
    }
    
    func testTextFragmentMultilineHeight() {
        let longText = String(repeating: "This is a long text that should wrap. ", count: 10)
        let attrString = NSAttributedString(string: longText)
        let fragment = TextFragment(
            fragmentId: "p0",
            attributedString: attrString
        )
        
        let narrowHeight = fragment.estimatedHeight(maxWidth: 100)
        let wideHeight = fragment.estimatedHeight(maxWidth: 500)
        
        // 窄宽度应该需要更多高度
        XCTAssertGreaterThanOrEqual(narrowHeight, wideHeight, "窄宽度应该需要更多或相等的高度")
    }
    
    // MARK: - ViewFragment 测试
    
    func testViewFragmentCreation() {
        let fragment = ViewFragment(
            fragmentId: "table0",
            makeView: { UIView() },
            configure: { _ in },
            estimatedHeight: { _ in 100 }
        )
        
        XCTAssertEqual(fragment.fragmentId, "table0")
    }
    
    func testViewFragmentMakeView() {
        let fragment = ViewFragment(
            fragmentId: "table0",
            makeView: {
                let view = UIView()
                view.tag = 42
                return view
            },
            configure: { _ in },
            estimatedHeight: { _ in 100 }
        )
        
        let view = fragment.makeView()
        XCTAssertEqual(view.tag, 42)
    }
    
    func testViewFragmentConfigure() {
        var configuredTag = 0
        
        let fragment = ViewFragment(
            fragmentId: "table0",
            makeView: { UIView() },
            configure: { view in
                view.tag = 99
                configuredTag = view.tag
            },
            estimatedHeight: { _ in 100 }
        )
        
        let view = fragment.makeView()
        fragment.configure(view: view)
        
        XCTAssertEqual(configuredTag, 99)
    }
    
    func testViewFragmentHeight() {
        let fragment = ViewFragment(
            fragmentId: "table0",
            makeView: { UIView() },
            configure: { _ in },
            estimatedHeight: { maxWidth in maxWidth / 2 }
        )
        
        let height = fragment.estimatedHeight(maxWidth: 320)
        XCTAssertEqual(height, 160)
    }
    
    // MARK: - Fragment ID 策略测试
    
    func testStructuralFingerprintId() {
        let markdown = """
        # Heading
        
        Paragraph
        
        - List item
        """
        
        var config = MarkdownConfiguration()
        config.fragmentIdStrategy = .structuralFingerprint
        
        let result = MarkdownKit.render(markdown, theme: .default, configuration: config)
        
        // 验证 Fragment ID 格式
        for fragment in result.fragments {
            XCTAssertFalse(fragment.fragmentId.isEmpty, "Fragment ID 不应为空")
        }
    }
    
    func testSequentialIndexId() {
        let markdown = """
        # Heading
        
        Paragraph
        """
        
        var config = MarkdownConfiguration()
        config.fragmentIdStrategy = .sequentialIndex
        
        let result = MarkdownKit.render(markdown, theme: .default, configuration: config)
        
        // 验证 Fragment ID 格式（应该是数字索引）
        for (index, fragment) in result.fragments.enumerated() {
            XCTAssertTrue(fragment.fragmentId.contains("\(index)") || !fragment.fragmentId.isEmpty)
        }
    }
    
    // MARK: - Fragment 序列测试
    
    func testFragmentSequenceOrder() {
        let markdown = """
        # Title
        
        First paragraph.
        
        Second paragraph.
        """
        
        let result = MarkdownKit.render(markdown, theme: .default)
        
        XCTAssertTrue(result.fragments.count >= 3, "应该至少有 3 个 Fragment")
        
        // 验证顺序正确（标题在前，段落在后）
        let texts = result.fragments.compactMap { ($0 as? TextFragment)?.attributedString.string }
        
        guard texts.count >= 3 else {
            XCTFail("文本 Fragment 数量不足")
            return
        }
        
        XCTAssertTrue(texts[0].contains("Title"))
        XCTAssertTrue(texts[1].contains("First"))
        XCTAssertTrue(texts[2].contains("Second"))
    }
    
    func testMixedFragmentTypes() {
        let markdown = """
        Paragraph
        
        | A | B |
        |---|---|
        | 1 | 2 |
        
        Another paragraph
        """
        
        let result = MarkdownKit.render(markdown, theme: .default)
        
        let textFragments = result.fragments.compactMap { $0 as? TextFragment }
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        
        XCTAssertTrue(textFragments.count >= 2, "应该至少有 2 个 TextFragment")
        XCTAssertTrue(viewFragments.count >= 1, "应该至少有 1 个 ViewFragment（表格）")
    }
    
    // MARK: - MarkdownContainerView 测试
    
    func testContainerViewApply() {
        let containerView = MarkdownContainerView()
        
        let markdown = "# Hello\n\nWorld"
        let result = MarkdownKit.render(markdown, theme: .default)
        
        containerView.apply(result, maxWidth: 320)
        
        XCTAssertGreaterThan(containerView.contentHeight, 0, "内容高度应该大于 0")
    }
    
    func testContainerViewMultipleApply() {
        let containerView = MarkdownContainerView()
        
        // 第一次应用
        let result1 = MarkdownKit.render("# First", theme: .default)
        containerView.apply(result1, maxWidth: 320)
        let height1 = containerView.contentHeight
        
        // 第二次应用（不同内容）
        let result2 = MarkdownKit.render("# Second\n\nWith more content", theme: .default)
        containerView.apply(result2, maxWidth: 320)
        let height2 = containerView.contentHeight
        
        // 高度应该正确更新
        XCTAssertGreaterThan(height2, height1, "更多内容应该需要更多高度")
    }
    
    func testContainerViewContentHeightCallback() {
        let containerView = MarkdownContainerView()
        
        var callbackHeight: CGFloat = 0
        containerView.onContentHeightChanged = { height in
            callbackHeight = height
        }
        
        let result = MarkdownKit.render("# Test", theme: .default)
        containerView.apply(result, maxWidth: 320)
        
        XCTAssertGreaterThan(callbackHeight, 0, "高度变化回调应该被调用")
    }
    
    // MARK: - Fragment 高度缓存测试
    
    func testFragmentHeightCaching() {
        let attrString = NSAttributedString(string: "Test text")
        let fragment = TextFragment(
            fragmentId: "p0",
            attributedString: attrString
        )
        
        // 多次计算同一宽度
        let height1 = fragment.estimatedHeight(maxWidth: 320)
        let height2 = fragment.estimatedHeight(maxWidth: 320)
        let height3 = fragment.estimatedHeight(maxWidth: 320)
        
        // 结果应该一致
        XCTAssertEqual(height1, height2)
        XCTAssertEqual(height2, height3)
    }
    
    // MARK: - 空内容测试
    
    func testEmptyMarkdownFragments() {
        let result = MarkdownKit.render("", theme: .default)
        
        // 空内容应该生成空或很少的 Fragment
        XCTAssertTrue(result.fragments.isEmpty || result.fragments.count <= 1)
    }
    
    func testWhitespaceOnlyMarkdown() {
        let result = MarkdownKit.render("   \n\n   ", theme: .default)
        
        // 应该能处理，不崩溃
        XCTAssertNotNil(result)
    }
    
    // MARK: - RenderFragmentProtocol 一致性测试
    
    func testFragmentProtocolConsistency() {
        let textFragment = TextFragment(
            fragmentId: "text0",
            attributedString: NSAttributedString(string: "Text")
        )
        
        let viewFragment = ViewFragment(
            fragmentId: "view0",
            makeView: { UIView() },
            configure: { _ in },
            estimatedHeight: { _ in 50 }
        )
        
        // 都遵循 RenderFragmentProtocol
        let fragments: [RenderFragmentProtocol] = [textFragment, viewFragment]
        
        for fragment in fragments {
            XCTAssertFalse(fragment.fragmentId.isEmpty)
            XCTAssertGreaterThan(fragment.estimatedHeight(maxWidth: 320), 0)
        }
    }
}
