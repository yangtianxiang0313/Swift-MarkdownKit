import XCTest
@testable import XHSMarkdownKit

/// 渲染性能测试
final class RenderPerformanceTests: XCTestCase {
    
    // MARK: - 基准性能测试
    
    /// 2000 字 Markdown 解析+渲染 < 50ms (目标)
    func testRenderPerformance2000Chars() {
        let markdown = generateMarkdown(targetLength: 2000)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    /// 500 字快速渲染测试
    func testRenderPerformance500Chars() {
        let markdown = generateMarkdown(targetLength: 500)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    /// 5000 字长文本测试
    func testRenderPerformance5000Chars() {
        let markdown = generateMarkdown(targetLength: 5000)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    // MARK: - 缓存性能测试
    
    /// 缓存命中时渲染 < 5ms (目标)
    func testCachedRenderPerformance() {
        let markdown = generateMarkdown(targetLength: 2000)
        
        // 首次渲染（填充缓存）
        _ = MarkdownKit.render(markdown, theme: .default)
        
        // 测量缓存命中后的性能
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    /// 不同文本缓存未命中测试
    func testUncachedRenderPerformance() {
        measure {
            // 每次使用不同的文本，避免缓存命中
            let markdown = generateMarkdown(targetLength: 1000, uniqueSuffix: UUID().uuidString)
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    // MARK: - 特定节点类型性能测试
    
    /// 复杂嵌套列表性能
    func testNestedListPerformance() {
        let markdown = generateNestedList(depth: 5, itemsPerLevel: 5)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    /// 大表格渲染性能
    func testLargeTablePerformance() {
        let markdown = generateTable(rows: 50, columns: 5)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    /// 多代码块性能
    func testMultipleCodeBlocksPerformance() {
        let markdown = generateCodeBlocks(count: 20, linesPerBlock: 10)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    /// 深度嵌套引用性能
    func testDeepBlockQuotePerformance() {
        let markdown = generateNestedBlockQuotes(depth: 10)
        
        measure {
            _ = MarkdownKit.render(markdown, theme: .default)
        }
    }
    
    // MARK: - 流式渲染性能测试
    
    /// 流式文本缓冲性能
    func testStreamingBufferPerformance() {
        let buffer = StreamingTextBuffer()
        let chunks = generateChunks(totalLength: 5000, chunkSize: 50)
        
        measure {
            for chunk in chunks {
                buffer.append(chunk)
            }
            buffer.finish()
        }
    }
    
    /// Fragment Diff 性能
    func testFragmentDiffPerformance() {
        let markdown1 = generateMarkdown(targetLength: 2000)
        let markdown2 = markdown1 + "\n\nAdditional paragraph."
        
        let result1 = MarkdownKit.render(markdown1, theme: .default)
        let result2 = MarkdownKit.render(markdown2, theme: .default)
        
        measure {
            _ = FragmentDiffer.diff(old: result1.fragments, new: result2.fragments)
        }
    }
    
    /// 预处理器性能（未闭合标记预闭合）
    func testPreprocessorPerformance() {
        // 包含未闭合标记的流式文本
        let streamingText = "# Title\n\n**Bold text that is not closed\n\n`code that is not closed"
        
        measure {
            for _ in 0..<100 {
                _ = MarkdownPreprocessor.preclose(streamingText)
            }
        }
    }
    
    // MARK: - ContainerView 布局性能
    
    func testContainerViewLayoutPerformance() {
        let markdown = generateMarkdown(targetLength: 3000)
        var config = MarkdownConfiguration.default
        config.maxWidth = 320
        let result = MarkdownKit.render(markdown, theme: .default, configuration: config)
        let containerView = MarkdownKit.makeContainerView(theme: .default, maxWidth: 320)
        
        measure {
            containerView.apply(result)
        }
    }
    
    func testContainerViewDiffApplyPerformance() {
        let markdown1 = generateMarkdown(targetLength: 2000)
        let markdown2 = markdown1 + "\n\n新增段落内容。"
        
        var config = MarkdownConfiguration.default
        config.maxWidth = 320
        let result1 = MarkdownKit.render(markdown1, theme: .default, configuration: config)
        let result2 = MarkdownKit.render(markdown2, theme: .default, configuration: config)
        
        let containerView = MarkdownKit.makeContainerView(theme: .default, maxWidth: 320)
        containerView.apply(result1)
        
        measure {
            containerView.apply(result2)
        }
    }
    
    // MARK: - 高度计算性能
    
    func testHeightCalculationPerformance() {
        let markdown = generateMarkdown(targetLength: 2000)
        let result = MarkdownKit.render(markdown, theme: .default)
        
        measure {
            var totalHeight: CGFloat = 0
            for fragment in result.fragments {
                totalHeight += fragment.estimatedHeight(maxWidth: 320)
            }
            _ = totalHeight
        }
    }
    
    // MARK: - 内存压力测试
    
    func testMemoryPressure() {
        // 连续渲染多个不同文档
        measure {
            for i in 0..<50 {
                let markdown = generateMarkdown(targetLength: 1000, uniqueSuffix: "doc\(i)")
                _ = MarkdownKit.render(markdown, theme: .default)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 生成指定长度的 Markdown 文本
    private func generateMarkdown(targetLength: Int, uniqueSuffix: String = "") -> String {
        var result = "# Performance Test\(uniqueSuffix.isEmpty ? "" : " \(uniqueSuffix)")\n\n"
        
        let paragraph = "This is a test paragraph with **bold**, *italic*, `code`, and [links](https://example.com). "
        
        while result.count < targetLength {
            result += paragraph
            
            if result.count < targetLength - 100 {
                result += "\n\n"
            }
            
            if result.count < targetLength - 200 {
                result += "- List item\n- Another item\n\n"
            }
        }
        
        return String(result.prefix(targetLength))
    }
    
    /// 生成嵌套列表
    private func generateNestedList(depth: Int, itemsPerLevel: Int) -> String {
        var result = "# Nested List\n\n"
        
        func addItems(level: Int) {
            let indent = String(repeating: "  ", count: level)
            for i in 1...itemsPerLevel {
                result += "\(indent)- Item \(level).\(i)\n"
                if level < depth {
                    addItems(level: level + 1)
                }
            }
        }
        
        addItems(level: 0)
        return result
    }
    
    /// 生成表格
    private func generateTable(rows: Int, columns: Int) -> String {
        var result = "# Large Table\n\n"
        
        // 表头
        result += "|"
        for c in 1...columns {
            result += " Col\(c) |"
        }
        result += "\n|"
        for _ in 1...columns {
            result += "------|"
        }
        result += "\n"
        
        // 数据行
        for r in 1...rows {
            result += "|"
            for c in 1...columns {
                result += " R\(r)C\(c) |"
            }
            result += "\n"
        }
        
        return result
    }
    
    /// 生成多个代码块
    private func generateCodeBlocks(count: Int, linesPerBlock: Int) -> String {
        var result = "# Code Blocks\n\n"
        
        for i in 1...count {
            result += "```swift\n"
            for l in 1...linesPerBlock {
                result += "let variable\(i)_\(l) = \(l * i)\n"
            }
            result += "```\n\n"
        }
        
        return result
    }
    
    /// 生成嵌套引用
    private func generateNestedBlockQuotes(depth: Int) -> String {
        var result = "# Nested Quotes\n\n"
        
        for level in 1...depth {
            let prefix = String(repeating: "> ", count: level)
            result += "\(prefix)Quote level \(level)\n"
        }
        
        return result
    }
    
    /// 生成流式 chunks
    private func generateChunks(totalLength: Int, chunkSize: Int) -> [String] {
        let fullText = generateMarkdown(targetLength: totalLength)
        var chunks: [String] = []
        var index = fullText.startIndex
        
        while index < fullText.endIndex {
            let endIndex = fullText.index(index, offsetBy: chunkSize, limitedBy: fullText.endIndex) ?? fullText.endIndex
            chunks.append(String(fullText[index..<endIndex]))
            index = endIndex
        }
        
        return chunks
    }
}
