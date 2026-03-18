import Foundation

// 集中维护 Streaming Demo 的场景与 mock 文本，方便直接调 chunk/network 参数。
enum StreamingDemoMockData {
    static let scenarios: [StreamingDemoScenario] = [
        .init(
            id: "full_coverage",
            title: "全量覆盖",
            userPrompt: "请给我一个覆盖核心 Markdown + 扩展节点的完整示例，并以流式输出。",
            assistantMarkdown: fullCoverageMarkdown,
            chunkProfile: .init(preferredCharacters: 22, jitterCharacters: -8...12),
            networkProfile: .init(
                ttfbMs: 120...280,
                receiveBytes: 24...72,
                interPacketMs: 40...140,
                stallProbability: 0.08,
                stallMs: 180...480,
                burstProbability: 0.35,
                burstReceiveBytes: 80...180,
                burstInterPacketMs: 12...50
            )
        ),
        .init(
            id: "nested_edge",
            title: "深嵌套",
            userPrompt: "重点看复杂嵌套和边界组合，确认行高回调和滚动跟随稳定。",
            assistantMarkdown: nestedEdgeMarkdown,
            chunkProfile: .init(preferredCharacters: 16, jitterCharacters: -6...8),
            networkProfile: .init(
                ttfbMs: 80...220,
                receiveBytes: 18...56,
                interPacketMs: 35...120,
                stallProbability: 0.15,
                stallMs: 220...620,
                burstProbability: 0.25,
                burstReceiveBytes: 66...140,
                burstInterPacketMs: 10...40
            )
        ),
        .init(
            id: "table_code_heavy",
            title: "表格代码",
            userPrompt: "给我一个以表格/代码/引用混合为主的长文示例，方便压测动画阶段布局变化。",
            assistantMarkdown: tableAndCodeHeavyMarkdown,
            chunkProfile: .init(preferredCharacters: 30, jitterCharacters: -10...14),
            networkProfile: .init(
                ttfbMs: 60...180,
                receiveBytes: 36...112,
                interPacketMs: 24...90,
                stallProbability: 0.05,
                stallMs: 160...360,
                burstProbability: 0.45,
                burstReceiveBytes: 120...240,
                burstInterPacketMs: 8...30
            )
        )
    ]
}

private extension StreamingDemoMockData {
    static let fullCoverageMarkdown = """
    # Streaming Full Coverage

    @Hero(title: "Streaming Full", subtitle: "core + extension nodes")

    @Callout(title: "Block Leaf")

    @Panel(style: "warning") {
    ### Panel Content
    - mention: <mention userId="stream-user-001" />
    - badge: <badge text="HOT" />
    - chip: <chip text="Regression" />
    - cite: <Cite id="stream-cite-001">reference-a</Cite>
    }

    @Tabs {
    - iOS
    - Android
    - Web
    }

    <Think id="think-stream-001">
    ### Thinking Flow
    1. parser 解析
    2. canonical 重写
    3. render model 输出
    4. scene 动画提交
    </Think>

    核心 inline 也要覆盖：**bold** / *italic* / ~~strike~~ / `inline code` / [link](https://example.com/stream?mode=full)。

    > 引用块内混合内容：
    > - 列表 A
    > - 列表 B
    >
    > 并包含 <spoiler text="spoiler-inline" />。

    1. 有序列表项 1
    2. 有序列表项 2
       - 子项 a
       - 子项 b

    - [x] task 完成
    - [ ] task 待处理

    ```swift
    let runtime = MarkdownRuntime()
    runtime.attach(to: markdownView)
    runtime.setStreamingRenderUpdate(update, mode: .incremental)
    ```

    | item | status | note |
    | --- | :---: | --- |
    | core markdown | ✅ | heading/list/quote/code/table |
    | extension nodes | ✅ | callout/panel/tabs/think/cite |
    | runtime chain | ✅ | stream -> diff -> animation |

    ---

    结束。请确认动画期间 cell 高度和滚动跟随逻辑稳定。
    """

    static let nestedEdgeMarkdown = """
    # Nested & Edge Case

    ## 多层引用 + 列表

    > 第一层
    > > 第二层
    > > > 第三层
    > > > - nested A
    > > > - nested B
    > > >   1. deeper 1
    > > >   2. deeper 2

    ## 混合列表

    - 无序 1
      1. 有序 1.1
      2. 有序 1.2
         - 无序 1.2.a
         - 无序 1.2.b
    - 无序 2

    ## 长段落

    这是一段比较长的段落，用于观察在流式增量渲染时，文本不断增长导致的换行变化、段落重排和 cell 高度连续变化行为，确保列表不会因为频繁重算而抖动。

    ## 扩展节点混排

    @Panel(style: "neutral") {
    - <mention userId="nested-user" />
    - <badge text="EDGE" />
    - <chip text="Nested" />
    }

    <Think id="think-edge-001">
    - 折叠状态由 runtime 管理
    - streaming 只负责模型增量
    </Think>

    <Cite id="edge-cite-001">edge-reference</Cite> + <spoiler text="edge-spoiler" />。

    ## 空块与分隔

    >

    -

    ---

    ***

    done.
    """

    static let tableAndCodeHeavyMarkdown = """
    # Table & Code Heavy

    @Callout(title: "Code First")

    ## Swift

    ```swift
    struct StreamState {
        let revision: Int
        let isFinal: Bool
        let documentID: String
    }

    func apply(update: MarkdownContract.StreamingRenderUpdate) {
        runtime.setStreamingRenderUpdate(update, mode: .incremental)
    }
    ```

    ## JSON

    ```json
    {
      "documentId": "example.streaming.demo",
      "revision": 12,
      "isFinal": false,
      "features": ["chunk", "height_callback", "auto_scroll"]
    }
    ```

    ## 表格矩阵

    | category | case | expectation | result |
    | --- | --- | --- | :---: |
    | list | nested ordered+unordered | layout stable | ✅ |
    | quote | deep quote + list | no jump | ✅ |
    | code | long block | no clipping | ✅ |
    | extension | panel/think/cite | parser+renderer pass | ✅ |

    ## 引用 + 代码

    > 测试建议：
    >
    > ```bash
    > xcodebuild -workspace ExampleApp.xcworkspace -scheme ExampleApp -destination 'generic/platform=iOS Simulator' build
    > ```
    >
    > 然后反复切换场景并观察滚动跟随。

    @Tabs {
    - Latency
    - Throughput
    - Stability
    }

    @Panel(style: "warning") {
    markdown 动画过程中，关注：
    1. height callback 频率
    2. table 重算开销
    3. 用户上滑后自动跟随是否退出
    }

    <Think id="table-code-think-001">
    - 若用户离开底部，暂停自动滚动
    - 若用户回到底部附近，恢复自动滚动
    </Think>

    收尾：<Cite id="tc-cite-001">table-code-ref</Cite>。
    """
}
