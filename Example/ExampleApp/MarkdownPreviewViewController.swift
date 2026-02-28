import UIKit
import XHSMarkdownKit

/// Markdown 预览页面
/// 提供实时编辑和预览 Markdown 的功能
class MarkdownPreviewViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["编辑", "预览", "分屏"])
        control.selectedSegmentIndex = 2
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.autocapitalizationType = .none
        tv.autocorrectionType = .no
        tv.backgroundColor = UIColor.systemGray6
        tv.layer.cornerRadius = 8
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        tv.delegate = self
        return tv
    }()
    
    private lazy var previewScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .systemBackground
        sv.layer.cornerRadius = 8
        sv.layer.borderWidth = 1
        sv.layer.borderColor = UIColor.systemGray4.cgColor
        return sv
    }()
    
    private lazy var containerView: MarkdownContainerView = {
        let view = MarkdownContainerView()
        view.delegate = self
        return view
    }()
    
    private lazy var sampleButton: UIBarButtonItem = {
        return UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(showSamples)
        )
    }()
    
    // MARK: - Properties
    
    private var currentTheme: MarkdownTheme = .default
    
    private let sampleMarkdowns: [(title: String, content: String)] = [
        ("基础语法", testHeight),
        ("列表", listSample),
        ("代码块", codeSample),
        ("表格", tableSample),
        ("混合内容", mixedSample),
        ("边界测试", edgeCaseSample)
    ]
    
    // 存储动态约束，方便切换时移除
    private var textViewTrailingConstraint: NSLayoutConstraint?
    private var textViewWidthConstraint: NSLayoutConstraint?
    private var textViewBottomConstraint: NSLayoutConstraint?
    private var previewLeadingConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDefaultSample()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 确保 previewScrollView 有有效尺寸后再渲染
        if previewScrollView.bounds.width > 0 && !previewScrollView.isHidden {
            renderMarkdown()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Markdown 预览"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = sampleButton
        
        // 布局
        view.addSubview(segmentedControl)
        view.addSubview(textView)
        view.addSubview(previewScrollView)
        previewScrollView.addSubview(containerView)
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false
        // containerView 使用 frame 布局，不使用 Auto Layout
        containerView.translatesAutoresizingMaskIntoConstraints = true
        
        // 固定约束
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            textView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            previewScrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            previewScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            previewScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        
        updateLayout(for: segmentedControl.selectedSegmentIndex)
    }
    
    private func loadDefaultSample() {
        textView.text = Self.testHeight
        renderMarkdown()
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        updateLayout(for: segmentedControl.selectedSegmentIndex)
    }
    
    @objc private func showSamples() {
        let alertController = UIAlertController(title: "选择示例", message: nil, preferredStyle: .actionSheet)
        
        for sample in sampleMarkdowns {
            alertController.addAction(UIAlertAction(title: sample.title, style: .default) { [weak self] _ in
                self?.textView.text = sample.content
                self?.renderMarkdown()
            })
        }
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            popover.barButtonItem = sampleButton
        }
        
        present(alertController, animated: true)
    }
    
    // MARK: - Layout
    
    private func updateLayout(for index: Int) {
        // 先移除所有动态约束
        textViewTrailingConstraint?.isActive = false
        textViewWidthConstraint?.isActive = false
        textViewBottomConstraint?.isActive = false
        previewLeadingConstraint?.isActive = false
        
        switch index {
        case 0: // 仅编辑
            textView.isHidden = false
            previewScrollView.isHidden = true
            
            textViewTrailingConstraint = textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            textViewBottomConstraint = textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
            
            textViewTrailingConstraint?.isActive = true
            textViewBottomConstraint?.isActive = true
            
        case 1: // 仅预览
            textView.isHidden = true
            previewScrollView.isHidden = false
            
            previewLeadingConstraint = previewScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
            previewLeadingConstraint?.isActive = true
            
        case 2: // 分屏
            textView.isHidden = false
            previewScrollView.isHidden = false
            
            textViewWidthConstraint = textView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5, constant: -24)
            textViewBottomConstraint = textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
            previewLeadingConstraint = previewScrollView.leadingAnchor.constraint(equalTo: textView.trailingAnchor, constant: 8)
            
            textViewWidthConstraint?.isActive = true
            textViewBottomConstraint?.isActive = true
            previewLeadingConstraint?.isActive = true
            
        default:
            break
        }
        
        view.layoutIfNeeded()
        
        if !previewScrollView.isHidden {
            renderMarkdown()
        }
    }
    
    // MARK: - Rendering
    
    private func renderMarkdown() {
        let markdown = textView.text ?? ""
        guard previewScrollView.bounds.width > 24 else { return }
        
        updateContainerFrame()
        containerView.setText(markdown)
    }
    
    private func updateContainerFrame() {
        let width = previewScrollView.bounds.width
        guard width > 0 else { return }
        
        containerView.frame = CGRect(
            x: 12,
            y: 12,
            width: width - 24,
            height: containerView.contentHeight
        )
    }
    
    private func updatePreviewContentSize() {
        let width = previewScrollView.bounds.width
        guard width > 0 else { return }
        
        updateContainerFrame()
        previewScrollView.contentSize = CGSize(width: width, height: containerView.contentHeight + 24)
    }
    
    // MARK: - Sample Markdown
    
    static let testHeight = """
    ## 嵌套引用
    
    > 外层引用
    > > 内层引用
    > > - 无序列表1
    > > - 无序列表2
    > > > 更深层引用
    """
    
    static let basicSample = """
    # 欢迎使用 XHSMarkdownKit
    
    这是一个功能完整的 Markdown 渲染库，支持以下特性：
    
    ## 文本样式
    
    - **加粗文本**
    - *斜体文本*
    - ~~删除线~~
    - `行内代码`
    
    ## 链接
    
    访问 [小红书](https://www.xiaohongshu.com) 了解更多。
    
    ## 引用
    
    > 这是一段引用文本。
    > 引用可以包含多行。
    
    ---
    
    *使用顶部按钮切换更多示例*
    """
    
    static let listSample = """
    # 列表示例
    
    ## 无序列表
    
    - 第一项
    - 第二项
      - 嵌套项 A
      - 嵌套项 B
        - 更深层嵌套
    - 第三项
    
    ## 有序列表
    
    1. 步骤一
    2. 步骤二
       1. 子步骤 2.1
       2. 子步骤 2.2
    3. 步骤三
    
    ## 任务列表
    
    - [x] 已完成任务
    - [ ] 未完成任务
    - [ ] 另一个任务
    """
    
    static let codeSample = """
    # 代码块示例
    
    ## Swift 代码
    
    ```swift
    import XHSMarkdownKit
    
    let markdown = \"\"\"
    # Hello World
    This is **bold** text.
    \"\"\"
    
    let container = MarkdownContainerView()
    container.setText(markdown)
    ```
    
    ## Python 代码
    
    ```python
    def hello_world():
        print("Hello, World!")
        return True
    
    if __name__ == "__main__":
        hello_world()
    ```
    
    ## 行内代码
    
    使用 `containerView.setText()` 方法渲染 Markdown。
    """
    
    static let tableSample = """
    # 表格示例
    
    ## 功能支持表
    
    | 功能 | 状态 | 说明 |
    |------|:----:|------|
    | 标题 | ✅ | H1-H6 |
    | 列表 | ✅ | 有序/无序/嵌套 |
    | 代码块 | ✅ | 多语言支持 |
    | 表格 | ✅ | 对齐/样式 |
    | 图片 | ✅ | URL 加载 |
    
    ## 对齐示例
    
    | 左对齐 | 居中 | 右对齐 |
    |:-------|:----:|-------:|
    | L1 | C1 | R1 |
    | L2 | C2 | R2 |
    """
    
    static let mixedSample = """
    # 混合内容示例
    
    这是一个包含多种元素的示例文档。
    
    ## 引用中的列表
    
    > 引用块可以包含：
    > 
    > - 列表项 1
    > - 列表项 2
    > 
    > 以及 **格式化文本**。
    
    ## 列表中的代码
    
    1. 首先，导入库：
       
       ```swift
       import XHSMarkdownKit
       ```
    
    2. 然后，渲染内容：
       
       ```swift
       let result = MarkdownKit.render(text)
       ```
    
    ## 嵌套引用
    
    > 外层引用
    > > 内层引用
    > > > 更深层引用
    
    ---
    
    **结束**
    """
    
    // MARK: - 边界测试用例
    
    static let edgeCaseSample = """
    # 边界测试用例
    
    本文档用于测试各种边界情况和嵌套组合。
    
    ---
    
    ## 1. 深层嵌套列表
    
    - 第一层
      - 第二层
        - 第三层
          - 第四层
            - 第五层
    
    1. 有序第一层
       1. 有序第二层
          1. 有序第三层
             1. 有序第四层
    
    ## 2. 混合列表嵌套
    
    - 无序项
      1. 嵌套有序 1
      2. 嵌套有序 2
         - 再嵌套无序
           1. 再嵌套有序
    
    ## 3. 引用块嵌套测试
    
    > 第一层引用
    >
    > > 第二层引用
    > >
    > > > 第三层引用
    > > >
    > > > 包含 **加粗** 和 *斜体*
    
    ## 4. 引用块内的列表
    
    > 引用块内容：
    >
    > - 列表项 A
    > - 列表项 B
    >   - 嵌套项 B.1
    >   - 嵌套项 B.2
    > - 列表项 C
    >
    > 引用结束。
    
    ## 5. 引用块内的有序列表
    
    > 步骤说明：
    >
    > 1. 第一步
    > 2. 第二步
    >    - 子步骤 A
    >    - 子步骤 B
    > 3. 第三步
    
    ## 6. 列表内的引用块
    
    - 普通列表项
    - 包含引用的列表项：
    
      > 这是嵌套在列表项内的引用块
      > 可以有多行
    
    - 后续列表项
    
    ## 7. 列表内的代码块
    
    1. 安装依赖：
    
       ```bash
       pod install
       ```
    
    2. 导入框架：
    
       ```swift
       import XHSMarkdownKit
       ```
    
    3. 使用：
    
       ```swift
       let container = MarkdownContainerView()
       container.setText(text)
       ```
    
    ## 8. 引用块内的代码块
    
    > 示例代码：
    >
    > ```python
    > def hello():
    >     print("Hello from quote!")
    > ```
    >
    > 以上是示例。
    
    ## 9. 复杂表格
    
    | 功能 | 描述 | 状态 | 备注 |
    |:-----|:-----|:----:|-----:|
    | **加粗标题** | 支持 `代码` | ✅ | 完成 |
    | *斜体内容* | [链接](https://example.com) | ⚠️ | 测试中 |
    | ~~删除线~~ | 普通文本 | ❌ | 待开发 |
    
    ## 10. 内联样式组合
    
    - **加粗** 和 *斜体* 组合
    - ***加粗斜体*** 样式
    - ~~删除线~~内容
    - `行内代码`样式
    - [超链接](https://example.com)
    - **加粗中的`代码`**
    - *斜体中的**加粗***
    
    ## 11. 任务列表
    
    - [x] 已完成任务
    - [ ] 未完成任务
    - [x] 另一个完成的任务
      - [ ] 嵌套未完成
      - [x] 嵌套已完成
    
    ## 12. 分隔线测试
    
    上方内容
    
    ---
    
    中间内容
    
    ***
    
    下方内容
    
    ## 13. 长代码块
    
    ```swift
    // 这是一个较长的代码块，用于测试横向滚动
    let container = MarkdownContainerView(theme: .default, pipeline: MarkdownRenderPipeline())
    container.animationDriver = TypingDriver(charactersPerSecond: 30, tickInterval: 1.0 / 60.0)
    container.delegate = self
    
    container.appendStreamChunk("# Hello World\n\nThis is a **streaming** demo with `TypingDriver` animation.")
    container.finishStreaming()
    ```
    
    ## 14. 空内容测试
    
    下面是空引用块：
    
    >
    
    下面是空列表项：
    
    -
    
    结束。
    
    ---
    
    **测试完成** ✅
    """
}

// MARK: - UITextViewDelegate

extension MarkdownPreviewViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        renderMarkdown()
    }
}

// MARK: - MarkdownContainerViewDelegate

extension MarkdownPreviewViewController: MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        updatePreviewContentSize()
    }
}
