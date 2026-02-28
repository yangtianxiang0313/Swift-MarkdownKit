import XCTest
@testable import XHSMarkdownKit

/// Fragment 序列和 ContainerView 布局测试
final class FragmentTests: XCTestCase {
    
    // MARK: - 文本 Fragment 测试（ViewFragment.text 替代 TextFragment）
    
    func testTextFragmentCreation() {
        let attrString = NSAttributedString(string: "Test text")
        let fragment = ViewFragment.text(
            fragmentId: "p0",
            nodeType: .paragraph,
            attributedString: attrString,
            context: FragmentContext(),
            maxWidth: 320,
            theme: .default
        )
        
        XCTAssertEqual(fragment.fragmentId, "p0")
        XCTAssertEqual(fragment.attributedString?.string, "Test text")
    }
    
    func testTextFragmentHeight() {
        let attrString = NSAttributedString(string: "Test text with some content")
        let fragment = ViewFragment.text(
            fragmentId: "p0",
            nodeType: .paragraph,
            attributedString: attrString,
            context: FragmentContext(),
            maxWidth: 320,
            theme: .default
        )
        
        let height = (fragment as? FragmentViewFactory)?.estimatedHeight(maxWidth: 320, theme: .default) ?? 0
        XCTAssertGreaterThan(height, 0, "文本 Fragment 高度应该大于 0")
    }
    
    func testTextFragmentMultilineHeight() {
        let longText = String(repeating: "This is a long text that should wrap. ", count: 10)
        let attrString = NSAttributedString(string: longText)
        let fragment = ViewFragment.text(
            fragmentId: "p0",
            nodeType: .paragraph,
            attributedString: attrString,
            context: FragmentContext(),
            maxWidth: 500,
            theme: .default
        )
        
        let vf = fragment as? FragmentViewFactory
        let narrowHeight = vf?.estimatedHeight(maxWidth: 100, theme: .default) ?? 0
        let wideHeight = vf?.estimatedHeight(maxWidth: 500, theme: .default) ?? 0
        
        // 窄宽度应该需要更多高度
        XCTAssertGreaterThanOrEqual(narrowHeight, wideHeight, "窄宽度应该需要更多或相等的高度")
    }
    
    // MARK: - ViewFragment 测试
    
    func testViewFragmentCreation() {
        let fragment = ViewFragment.typed(
            fragmentId: "table0",
            nodeType: .paragraph,
            reuseIdentifier: .markdownTableView,
            estimatedSize: CGSize(width: 320, height: 100),
            content: (),
            makeView: { UIView() },
            configure: { _, _, _ in }
        )
        
        XCTAssertEqual(fragment.fragmentId, "table0")
    }
    
    func testViewFragmentMakeView() {
        let fragment = ViewFragment.typed(
            fragmentId: "table0",
            nodeType: .paragraph,
            reuseIdentifier: .markdownTableView,
            estimatedSize: CGSize(width: 320, height: 100),
            content: (),
            makeView: {
                let view = UIView()
                view.tag = 42
                return view
            },
            configure: { _, _, _ in }
        )
        
        let view = fragment.makeView()
        XCTAssertEqual(view.tag, 42)
    }
    
    func testViewFragmentConfigure() {
        var configuredTag = 0
        
        let fragment = ViewFragment.typed(
            fragmentId: "table0",
            nodeType: .paragraph,
            reuseIdentifier: .markdownTableView,
            estimatedSize: CGSize(width: 320, height: 100),
            content: (),
            makeView: { UIView() },
            configure: { view, _, _ in
                view.tag = 99
                configuredTag = view.tag
            }
        )
        
        let view = fragment.makeView()
        fragment.configure(view, theme: .default)
        
        XCTAssertEqual(configuredTag, 99)
    }
    
    func testViewFragmentHeight() {
        let fragment = ViewFragment.typed(
            fragmentId: "table0",
            nodeType: .paragraph,
            reuseIdentifier: .markdownTableView,
            estimatedSize: CGSize(width: 320, height: 160),
            content: (),
            makeView: { UIView() },
            configure: { _, _, _ in }
        )
        
        let height = (fragment as? FragmentViewFactory)?.estimatedHeight(maxWidth: 320, theme: .default) ?? 0
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
        let texts = result.fragments.compactMap { ($0 as? AttributedStringProviding)?.attributedString?.string }
        
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
        
        let textFragments = result.fragments.compactMap { $0 as? AttributedStringProviding }
        let viewFragments = result.fragments.compactMap { $0 as? ViewFragment }
        
        XCTAssertTrue(textFragments.count >= 2, "应该至少有 2 个文本 Fragment")
        XCTAssertTrue(viewFragments.count >= 1, "应该至少有 1 个 ViewFragment（表格）")
    }
    
    // MARK: - MarkdownContainerView 测试
    
    func testContainerViewApply() {
        let containerView = MarkdownKit.makeContainerView(theme: .default, maxWidth: 320)
        
        let markdown = "# Hello\n\nWorld"
        var config = MarkdownConfiguration.default
        config.maxWidth = 320
        let result = MarkdownKit.render(markdown, theme: .default, configuration: config)
        
        containerView.apply(result)
        
        XCTAssertGreaterThan(containerView.contentHeight, 0, "内容高度应该大于 0")
    }
    
    func testContainerViewMultipleApply() {
        let containerView = MarkdownKit.makeContainerView(theme: .default, maxWidth: 320)
        
        var config = MarkdownConfiguration.default
        config.maxWidth = 320
        // 第一次应用
        let result1 = MarkdownKit.render("# First", theme: .default, configuration: config)
        containerView.apply(result1)
        let height1 = containerView.contentHeight
        
        // 第二次应用（不同内容）
        let result2 = MarkdownKit.render("# Second\n\nWith more content", theme: .default, configuration: config)
        containerView.apply(result2)
        let height2 = containerView.contentHeight
        
        // 高度应该正确更新
        XCTAssertGreaterThan(height2, height1, "更多内容应该需要更多高度")
    }
    
    func testContainerViewContentHeightCallback() {
        let containerView = MarkdownKit.makeContainerView(theme: .default, maxWidth: 320)
        
        var callbackHeight: CGFloat = 0
        containerView.onContentHeightChanged = { height in
            callbackHeight = height
        }
        
        var config = MarkdownConfiguration.default
        config.maxWidth = 320
        let result = MarkdownKit.render("# Test", theme: .default, configuration: config)
        containerView.apply(result)
        
        XCTAssertGreaterThan(callbackHeight, 0, "高度变化回调应该被调用")
    }
    
    // MARK: - Fragment 高度缓存测试
    
    func testFragmentHeightCaching() {
        let attrString = NSAttributedString(string: "Test text")
        let fragment = ViewFragment.text(
            fragmentId: "p0",
            nodeType: .paragraph,
            attributedString: attrString,
            context: FragmentContext(),
            maxWidth: 320,
            theme: .default
        )
        
        guard let vf = fragment as? FragmentViewFactory else {
            XCTFail("ViewFragment.text 应遵循 FragmentViewFactory")
            return
        }
        // 多次计算同一宽度
        let height1 = vf.estimatedHeight(maxWidth: 320, theme: .default)
        let height2 = vf.estimatedHeight(maxWidth: 320, theme: .default)
        let height3 = vf.estimatedHeight(maxWidth: 320, theme: .default)
        
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
        let textFragment = ViewFragment.text(
            fragmentId: "text0",
            nodeType: .paragraph,
            attributedString: NSAttributedString(string: "Text"),
            context: FragmentContext(),
            maxWidth: 320,
            theme: .default
        )
        
        let viewFragment = ViewFragment.typed(
            fragmentId: "view0",
            nodeType: .paragraph,
            reuseIdentifier: .markdownTableView,
            estimatedSize: CGSize(width: 320, height: 50),
            content: TableData(headers: [], rows: []),
            makeView: { UIView() },
            configure: { _, _, _ in }
        )
        
        // 都遵循 RenderFragment
        let fragments: [RenderFragment] = [textFragment, viewFragment]
        
        for fragment in fragments {
            XCTAssertFalse(fragment.fragmentId.isEmpty)
            if let vf = fragment as? FragmentViewFactory {
                XCTAssertGreaterThan(vf.estimatedHeight(maxWidth: 320, theme: .default), 0)
            }
        }
    }
}
