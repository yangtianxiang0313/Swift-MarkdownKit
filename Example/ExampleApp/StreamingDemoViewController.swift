import UIKit
import XHSMarkdownKit

/// 流式渲染演示页面
/// 支持选择渲染内容、滚动跟随、参数配置、自定义内容
class StreamingDemoViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = UIColor.systemGray6
        sv.layer.cornerRadius = 12
        sv.alwaysBounceVertical = true
        return sv
    }()
    
    private lazy var containerView: MarkdownContainerView = {
        let engine = MarkdownRenderEngine.makeDefault()
        let view = MarkdownContainerView(engine: engine)
        view.onContentHeightChanged = { [weak self] height in
            self?.updateScrollViewContentSize()
            if self?.autoScrollEnabled == true {
                self?.scrollToBottom()
            }
        }
        return view
    }()
    
    /// 内容选择器
    private lazy var caseSelector: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("选择内容", for: .normal)
        button.setImage(UIImage(systemName: "doc.text"), for: .normal)
        button.backgroundColor = .systemBackground
        button.setTitleColor(.label, for: .normal)
        button.tintColor = .label
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.separator.cgColor
        button.showsMenuAsPrimaryAction = true
        button.menu = createCaseMenu()
        return button
    }()
    
    /// 配置区域
    private lazy var configStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    /// 渲染速度标签
    private lazy var speedLabel: UILabel = {
        let label = UILabel()
        label.text = "渲染: 1字/秒"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()
    
    /// 渲染速度滑块（0-100，映射到不同速度档位）
    private lazy var speedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 30  // 默认 1字/秒
        slider.minimumTrackTintColor = .systemBlue
        slider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        return slider
    }()
    
    /// 网络接收速度标签
    private lazy var networkSpeedLabel: UILabel = {
        let label = UILabel()
        label.text = "网络: 3字/秒"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()
    
    /// 网络接收速度滑块
    private lazy var networkSpeedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50  // 默认比渲染快
        slider.minimumTrackTintColor = .systemGreen
        slider.addTarget(self, action: #selector(networkSpeedChanged), for: .valueChanged)
        return slider
    }()
    
    /// 积压显示标签
    private lazy var backlogLabel: UILabel = {
        let label = UILabel()
        label.text = "📦 积压: 0 字"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemGray
        return label
    }()
    
    /// 滚动跟随开关
    private lazy var autoScrollSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        sw.addTarget(self, action: #selector(autoScrollChanged), for: .valueChanged)
        return sw
    }()
    
    /// 网络模式开关（不稳定/稳定）
    private lazy var networkModeSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = false  // 默认关闭不稳定模式，方便观察
        sw.onTintColor = .systemOrange
        sw.addTarget(self, action: #selector(networkModeChanged), for: .valueChanged)
        return sw
    }()
    
    /// 网络模式标签
    private lazy var networkModeLabel: UILabel = {
        let label = UILabel()
        label.text = "🔗 稳定网络模式"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemGreen
        return label
    }()
    
    /// 网络质量滑块（控制抖动频率、延迟概率等）
    private lazy var networkQualitySlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50  // 默认中等质量
        slider.minimumTrackTintColor = .systemOrange
        slider.addTarget(self, action: #selector(networkQualityChanged), for: .valueChanged)
        return slider
    }()
    
    /// 网络质量标签
    private lazy var networkQualityLabel: UILabel = {
        let label = UILabel()
        label.text = "网络质量: 中等"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()
    
    /// 自动加速开关
    private lazy var autoAccelerateSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true  // 默认开启
        sw.onTintColor = .systemBlue
        sw.addTarget(self, action: #selector(autoAccelerateChanged), for: .valueChanged)
        return sw
    }()
    
    /// 自动加速标签
    private lazy var autoAccelerateLabel: UILabel = {
        let label = UILabel()
        label.text = "🚀 自动加速: 线性"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemBlue
        return label
    }()
    
    /// 加速算法选择按钮
    private lazy var algorithmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("线性加速", for: .normal)
        button.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.15)
        button.setTitleColor(.systemBlue, for: .normal)
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 6
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.showsMenuAsPrimaryAction = true
        button.menu = createAlgorithmMenu()
        return button
    }()
    
    private lazy var controlStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }()
    
    private lazy var startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始", for: .normal)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(startStreaming), for: .touchUpInside)
        return button
    }()
    
    private lazy var pauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("暂停", for: .normal)
        button.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重置", for: .normal)
        button.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(resetStreaming), for: .touchUpInside)
        return button
    }()
    
    private lazy var fastForwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("快进", for: .normal)
        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(fastForward), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private lazy var addCaseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ 自定义", for: .normal)
        button.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        button.backgroundColor = .systemPurple
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(addCustomCase), for: .touchUpInside)
        return button
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "点击「开始」模拟流式渲染"
        return label
    }()
    
    // MARK: - Properties
    
    private var streamingTimer: Timer?
    private var networkTimer: Timer?  // 模拟网络接收的定时器
    private var streamingBuffer: [Character] = []
    private var currentIndex = 0        // 网络已接收到的位置
    private var renderedIndex = 0       // 已渲染的位置
    private var lastAppendedIndex = 0    // 已通过 appendText 发送到 container 的位置
    private var isPaused = false
    private var autoScrollEnabled = true
    
    /// 当前选中的 case 索引
    private var selectedCaseIndex = 0
    
    // MARK: - 速度配置
    
    /// 渲染速度配置
    private var renderSpeed: SpeedConfig = .charsPerSecond(1)
    
    /// 网络接收速度配置
    private var networkSpeed: SpeedConfig = .charsPerSecond(3)
    
    /// 速度配置枚举
    private enum SpeedConfig {
        case charsPerInterval(chars: Int, interval: TimeInterval)  // N字/间隔
        case charsPerSecond(Int)                                    // N字/秒
        case charsPerFrame(Int)                                     // N字/帧（高速模式）
        
        var description: String {
            switch self {
            case .charsPerInterval(let chars, let interval):
                if interval >= 1 {
                    return "\(chars)字/\(Int(interval))秒"
                } else {
                    return "\(chars)字/\(String(format: "%.1f", interval))秒"
                }
            case .charsPerSecond(let n):
                return "\(n)字/秒"
            case .charsPerFrame(let n):
                return "\(n)字/帧(极速)"
            }
        }
        
        /// 转换为 Timer 间隔和每次字符数
        func timerConfig() -> (interval: TimeInterval, chars: Int, useDisplayLink: Bool) {
            switch self {
            case .charsPerInterval(let chars, let interval):
                return (interval, chars, false)
            case .charsPerSecond(let n):
                if n <= 10 {
                    return (1.0 / Double(n), 1, false)
                } else {
                    // 高速模式用更短间隔
                    return (0.05, max(1, n / 20), false)
                }
            case .charsPerFrame(let n):
                return (1.0 / 60.0, n, true)
            }
        }
    }
    
    // MARK: - 自动加速配置
    
    /// 是否启用自动加速
    private var autoAccelerateEnabled = true
    
    /// 自动加速算法
    private var accelerateAlgorithm: AccelerateAlgorithm = .linear
    
    /// 加速算法枚举
    private enum AccelerateAlgorithm: String, CaseIterable {
        case linear = "线性加速"
        case exponential = "指数加速"
        case step = "阶梯加速"
        case adaptive = "自适应加速"
        
        var icon: String {
            switch self {
            case .linear: return "chart.line.uptrend.xyaxis"
            case .exponential: return "chart.line.uptrend.xyaxis.circle"
            case .step: return "stairs"
            case .adaptive: return "waveform.path.ecg"
            }
        }
        
        /// 计算加速后的字符数
        func acceleratedChars(baseChars: Int, progress: Double, backlog: Int) -> Int {
            switch self {
            case .linear:
                // 线性加速：随进度线性增加
                let multiplier = 1.0 + progress * 2.0  // 最多 3x
                return max(1, Int(Double(baseChars) * multiplier))
                
            case .exponential:
                // 指数加速：后期急剧加速
                let multiplier = pow(3.0, progress)  // 1x -> 3x
                return max(1, Int(Double(baseChars) * multiplier))
                
            case .step:
                // 阶梯加速：每 25% 提速一档
                let step: Double
                if progress < 0.25 { step = 1.0 }
                else if progress < 0.5 { step = 1.5 }
                else if progress < 0.75 { step = 2.5 }
                else { step = 4.0 }
                return max(1, Int(Double(baseChars) * step))
                
            case .adaptive:
                // 自适应加速：根据积压量动态调整
                if backlog > 100 {
                    return baseChars * 5  // 积压多，快速追赶
                } else if backlog > 50 {
                    return baseChars * 3
                } else if backlog > 20 {
                    return baseChars * 2
                }
                return baseChars
            }
        }
    }
    
    /// 积压字符数（模拟服务端发送但未渲染的数据）
    private var backlogChars = 0
    
    // MARK: - 不稳定网络模拟
    
    /// 是否启用不稳定网络模拟
    private var unstableNetworkEnabled = false  // 默认关闭
    
    /// 网络质量配置（0-100，100 最好）
    private var networkQuality: Int = 50
    
    /// 网络质量参数（根据 networkQuality 计算）
    private var networkParams: NetworkParams {
        NetworkParams(quality: networkQuality)
    }
    
    /// 网络参数结构体
    private struct NetworkParams {
        let jitterProbability: Int      // 抖动概率 (0-100)
        let jitterDuration: ClosedRange<Int>  // 抖动持续 tick 数
        let skipProbability: Int        // 跳过概率 (0-100)
        let burstProbability: Int       // 爆发概率 (0-100)
        let burstMultiplier: ClosedRange<Int>  // 爆发倍数
        let variationRange: Int         // 数据包大小波动范围（基础值的倍数）
        
        init(quality: Int) {
            // quality: 0=极差, 50=中等, 100=极好
            let badness = 100 - quality  // 反转：0=极好, 100=极差
            
            // 抖动概率: 0-15%
            jitterProbability = badness * 15 / 100
            
            // 抖动持续时间: 质量越差，持续越长
            let minJitter = max(1, badness / 20)
            let maxJitter = max(2, badness / 10)
            jitterDuration = minJitter...maxJitter
            
            // 跳过概率: 0-30%
            skipProbability = badness * 30 / 100
            
            // 爆发概率: 质量差时更可能爆发（补偿延迟）
            burstProbability = badness * 15 / 100
            
            // 爆发倍数
            let minBurst = 2
            let maxBurst = max(3, 2 + badness / 20)
            burstMultiplier = minBurst...maxBurst
            
            // 数据包波动范围
            variationRange = max(1, badness / 25)
        }
        
        var description: String {
            let quality = 100 - (jitterProbability * 100 / 15)
            switch quality {
            case 90...100: return "极好"
            case 70..<90: return "良好"
            case 40..<70: return "中等"
            case 20..<40: return "较差"
            default: return "极差"
            }
        }
    }
    
    /// 跳过计数器（模拟延迟）
    private var skipTickCount = 0
    
    /// 抖动剩余次数
    private var jitterTicksRemaining = 0
    
    /// 累计 tick 数
    private var tickCounter = 0
    
    /// 预设的测试内容
    private var testCases: [(name: String, content: String)] = [
        ("基础演示", StreamingDemoViewController.basicDemo),
        ("代码块测试", StreamingDemoViewController.codeBlockDemo),
        ("表格测试", StreamingDemoViewController.tableDemo),
        ("列表嵌套", StreamingDemoViewController.nestedListDemo),
        ("引用块测试", StreamingDemoViewController.blockQuoteDemo),
        ("长文本测试", StreamingDemoViewController.longTextDemo),
        ("混合内容", StreamingDemoViewController.mixedDemo),
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateCaseSelector()
        setupStreamingBuffer()
        
        // 初始化速度和加速状态
        speedChanged()
        networkSpeedChanged()
        updateAutoAccelerateLabel()
        updateNetworkQualityLabel()
        updateBacklogLabel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewContentSize()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "流式渲染"
        
        // 添加导航栏按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
        view.addSubview(caseSelector)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(configStack)
        view.addSubview(controlStack)
        view.addSubview(statusLabel)
        
        // 配置区域
        let networkSpeedRow = createRow(label: "网络接收", control: networkSpeedSlider)
        let speedRow = createRow(label: "渲染速度", control: speedSlider)
        let autoScrollRow = createRow(label: "滚动跟随", control: autoScrollSwitch)
        let networkModeRow = createRow(label: "网络抖动", control: networkModeSwitch)
        let autoAccelerateRow = createRowWithButton(
            label: "自动加速",
            control: autoAccelerateSwitch,
            button: algorithmButton
        )
        
        // 速度相关
        configStack.addArrangedSubview(networkSpeedRow)
        configStack.addArrangedSubview(networkSpeedLabel)
        configStack.addArrangedSubview(speedRow)
        configStack.addArrangedSubview(speedLabel)
        configStack.addArrangedSubview(backlogLabel)
        
        // 功能开关
        configStack.addArrangedSubview(autoScrollRow)
        configStack.addArrangedSubview(autoAccelerateRow)
        configStack.addArrangedSubview(autoAccelerateLabel)
        configStack.addArrangedSubview(networkModeRow)
        configStack.addArrangedSubview(networkModeLabel)
        
        // 网络质量滑块（仅在不稳定模式下显示）
        let networkQualityRow = createRow(label: "网络质量", control: networkQualitySlider)
        configStack.addArrangedSubview(networkQualityRow)
        configStack.addArrangedSubview(networkQualityLabel)
        updateNetworkQualityVisibility()
        
        // 控制按钮
        controlStack.addArrangedSubview(startButton)
        controlStack.addArrangedSubview(pauseButton)
        controlStack.addArrangedSubview(fastForwardButton)
        controlStack.addArrangedSubview(resetButton)
        
        // 约束
        caseSelector.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        configStack.translatesAutoresizingMaskIntoConstraints = false
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            caseSelector.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            caseSelector.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            caseSelector.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            caseSelector.heightAnchor.constraint(equalToConstant: 40),
            
            scrollView.topAnchor.constraint(equalTo: caseSelector.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: configStack.topAnchor, constant: -12),
            
            configStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            configStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            configStack.bottomAnchor.constraint(equalTo: controlStack.topAnchor, constant: -12),
            
            controlStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlStack.heightAnchor.constraint(equalToConstant: 44),
            controlStack.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),
            
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }
    
    private func createRow(label: String, control: UIView) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14)
        labelView.textColor = .secondaryLabel
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(control)
        
        return row
    }
    
    private func createRowWithButton(label: String, control: UIView, button: UIButton) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14)
        labelView.textColor = .secondaryLabel
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(control)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(button)
        
        return row
    }
    
    private func createAlgorithmMenu() -> UIMenu {
        let actions = AccelerateAlgorithm.allCases.map { algorithm in
            UIAction(
                title: algorithm.rawValue,
                image: UIImage(systemName: algorithm.icon),
                state: algorithm == self.accelerateAlgorithm ? .on : .off
            ) { [weak self] _ in
                self?.selectAlgorithm(algorithm)
            }
        }
        return UIMenu(title: "选择加速算法", children: actions)
    }
    
    private func selectAlgorithm(_ algorithm: AccelerateAlgorithm) {
        accelerateAlgorithm = algorithm
        algorithmButton.setTitle(algorithm.rawValue, for: .normal)
        algorithmButton.menu = createAlgorithmMenu()
        updateAutoAccelerateLabel()
    }
    
    private func updateAutoAccelerateLabel() {
        if autoAccelerateEnabled {
            autoAccelerateLabel.text = "🚀 自动加速: \(accelerateAlgorithm.rawValue)"
            autoAccelerateLabel.textColor = .systemBlue
        } else {
            autoAccelerateLabel.text = "⏸️ 自动加速: 已关闭"
            autoAccelerateLabel.textColor = .secondaryLabel
        }
    }
    
    private func createCaseMenu() -> UIMenu {
        var actions: [UIMenuElement] = testCases.enumerated().map { index, testCase in
            UIAction(
                title: testCase.name,
                state: index == selectedCaseIndex ? .on : .off
            ) { [weak self] _ in
                self?.selectCase(at: index)
            }
        }
        
        // 添加分隔线和自定义选项
        let addAction = UIAction(
            title: "添加自定义内容...",
            image: UIImage(systemName: "plus.circle")
        ) { [weak self] _ in
            self?.addCustomCase()
        }
        
        return UIMenu(children: actions + [addAction])
    }
    
    private func updateCaseSelector() {
        let caseName = testCases[selectedCaseIndex].name
        caseSelector.setTitle("📄 \(caseName)", for: .normal)
        caseSelector.menu = createCaseMenu()
    }
    
    private func selectCase(at index: Int) {
        selectedCaseIndex = index
        updateCaseSelector()
        resetStreaming()
    }
    
    private func setupStreamingBuffer() {
        let content = testCases[selectedCaseIndex].content
        streamingBuffer = Array(content)
    }
    
    // MARK: - Actions
    
    @objc private func startStreaming() {
        guard streamingTimer == nil && networkTimer == nil else { return }
        
        containerView.startStreaming()
        startNetworkTimer()
        startRenderTimer()
        
        startButton.isEnabled = false
        pauseButton.isEnabled = true
        fastForwardButton.isEnabled = true
        
        statusLabel.text = "正在流式渲染..."
    }
    
    /// 启动网络接收定时器（模拟服务端发送数据）
    private func startNetworkTimer() {
        let config = networkSpeed.timerConfig()
        networkTimer?.invalidate()
        networkTimer = Timer.scheduledTimer(
            timeInterval: config.interval,
            target: self,
            selector: #selector(networkTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.current.add(networkTimer!, forMode: .common)
    }
    
    /// 启动渲染定时器（消费已接收的数据）
    private func startRenderTimer() {
        let config = renderSpeed.timerConfig()
        streamingTimer?.invalidate()
        streamingTimer = Timer.scheduledTimer(
            timeInterval: config.interval,
            target: self,
            selector: #selector(renderTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.current.add(streamingTimer!, forMode: .common)
    }
    
    private func restartNetworkTimerIfNeeded() {
        if networkTimer != nil && !isPaused {
            startNetworkTimer()
        }
    }
    
    private func restartRenderTimerIfNeeded() {
        if streamingTimer != nil && !isPaused {
            startRenderTimer()
        }
    }
    
    @objc private func togglePause() {
        isPaused.toggle()
        pauseButton.setTitle(isPaused ? "继续" : "暂停", for: .normal)
        pauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"), for: .normal)
        statusLabel.text = isPaused ? "已暂停" : "正在流式渲染..."
        
        if isPaused {
            streamingTimer?.invalidate()
            streamingTimer = nil
            networkTimer?.invalidate()
            networkTimer = nil
        } else {
            startNetworkTimer()
            startRenderTimer()
        }
    }
    
    @objc private func fastForward() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        networkTimer?.invalidate()
        networkTimer = nil
        
        let fullText = testCases[selectedCaseIndex].content
        containerView.render(fullText)
        containerView.endStreaming()
        
        currentIndex = streamingBuffer.count
        renderedIndex = streamingBuffer.count
        
        startButton.isEnabled = false
        pauseButton.isEnabled = false
        fastForwardButton.isEnabled = false
        
        statusLabel.text = "渲染完成 (\(streamingBuffer.count) 字符)"
        updateBacklogLabel()
        
        if autoScrollEnabled {
            scrollToBottom()
        }
    }
    
    @objc private func resetStreaming() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        networkTimer?.invalidate()
        networkTimer = nil
        
        currentIndex = 0
        renderedIndex = 0
        lastAppendedIndex = 0
        isPaused = false
        
        // 重置网络模拟状态
        skipTickCount = 0
        jitterTicksRemaining = 0
        tickCounter = 0
        backlogChars = 0
        
        setupStreamingBuffer()
        containerView.clear()
        
        startButton.isEnabled = true
        pauseButton.isEnabled = false
        fastForwardButton.isEnabled = false
        pauseButton.setTitle("暂停", for: .normal)
        pauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        statusLabel.text = "点击「开始」模拟流式渲染"
    }
    
    @objc private func speedChanged() {
        // 滑块值 0-100 映射到不同速度档位
        let value = speedSlider.value
        
        if value < 10 {
            // 超慢速: 1字/3秒 ~ 1字/1秒
            let interval = 3.0 - (Double(value) / 10.0 * 2.0)  // 3秒 -> 1秒
            renderSpeed = .charsPerInterval(chars: 1, interval: interval)
        } else if value < 30 {
            // 慢速: 1字/秒 ~ 3字/秒
            let cps = 1 + Int((value - 10) / 10 * 2)
            renderSpeed = .charsPerSecond(cps)
        } else if value < 60 {
            // 正常: 3字/秒 ~ 15字/秒
            let cps = 3 + Int((value - 30) / 30 * 12)
            renderSpeed = .charsPerSecond(cps)
        } else if value < 85 {
            // 快速: 15字/秒 ~ 50字/秒
            let cps = 15 + Int((value - 60) / 25 * 35)
            renderSpeed = .charsPerSecond(cps)
        } else {
            // 极速: 2字/帧 ~ 10字/帧
            let cpf = 2 + Int((value - 85) / 15 * 8)
            renderSpeed = .charsPerFrame(cpf)
        }
        
        speedLabel.text = "渲染: \(renderSpeed.description)"
        restartRenderTimerIfNeeded()
    }
    
    @objc private func networkSpeedChanged() {
        let value = networkSpeedSlider.value
        
        if value < 10 {
            // 超慢速: 1字/3秒 ~ 1字/1秒
            let interval = 3.0 - (Double(value) / 10.0 * 2.0)
            networkSpeed = .charsPerInterval(chars: 1, interval: interval)
        } else if value < 30 {
            // 慢速: 1字/秒 ~ 3字/秒
            let cps = 1 + Int((value - 10) / 10 * 2)
            networkSpeed = .charsPerSecond(cps)
        } else if value < 60 {
            // 正常: 3字/秒 ~ 15字/秒
            let cps = 3 + Int((value - 30) / 30 * 12)
            networkSpeed = .charsPerSecond(cps)
        } else if value < 85 {
            // 快速: 15字/秒 ~ 50字/秒
            let cps = 15 + Int((value - 60) / 25 * 35)
            networkSpeed = .charsPerSecond(cps)
        } else {
            // 极速: 2字/帧 ~ 10字/帧
            let cpf = 2 + Int((value - 85) / 15 * 8)
            networkSpeed = .charsPerFrame(cpf)
        }
        
        networkSpeedLabel.text = "网络: \(networkSpeed.description)"
        restartNetworkTimerIfNeeded()
    }
    
    @objc private func autoScrollChanged() {
        autoScrollEnabled = autoScrollSwitch.isOn
    }
    
    @objc private func autoAccelerateChanged() {
        autoAccelerateEnabled = autoAccelerateSwitch.isOn
        algorithmButton.isEnabled = autoAccelerateEnabled
        algorithmButton.alpha = autoAccelerateEnabled ? 1.0 : 0.5
        updateAutoAccelerateLabel()
    }
    
    @objc private func networkModeChanged() {
        unstableNetworkEnabled = networkModeSwitch.isOn
        
        if unstableNetworkEnabled {
            networkModeLabel.text = "📶 不稳定网络模拟"
            networkModeLabel.textColor = .systemOrange
        } else {
            networkModeLabel.text = "🔗 稳定网络模式"
            networkModeLabel.textColor = .systemGreen
        }
        
        updateNetworkQualityVisibility()
    }
    
    @objc private func networkQualityChanged() {
        networkQuality = Int(networkQualitySlider.value)
        updateNetworkQualityLabel()
    }
    
    private func updateNetworkQualityVisibility() {
        let shouldShow = unstableNetworkEnabled
        networkQualitySlider.superview?.isHidden = !shouldShow
        networkQualityLabel.isHidden = !shouldShow
    }
    
    private func updateNetworkQualityLabel() {
        let params = networkParams
        let qualityText = params.description
        networkQualityLabel.text = "网络质量: \(qualityText) (抖动:\(params.jitterProbability)% 跳过:\(params.skipProbability)%)"
    }
    
    @objc private func showSettings() {
        let alert = UIAlertController(title: "设置", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "导出当前内容", style: .default) { [weak self] _ in
            self?.exportCurrentContent()
        })
        
        alert.addAction(UIAlertAction(title: "清除自定义内容", style: .destructive) { [weak self] _ in
            self?.clearCustomCases()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func addCustomCase() {
        let alert = UIAlertController(
            title: "添加自定义内容",
            message: "输入 Markdown 内容",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "名称"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Markdown 内容（支持多行）"
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            guard let name = alert.textFields?[0].text, !name.isEmpty,
                  let content = alert.textFields?[1].text, !content.isEmpty else { return }
            
            self?.addTestCase(name: name, content: content)
        })
        
        // 添加长文本输入选项
        alert.addAction(UIAlertAction(title: "从剪贴板粘贴", style: .default) { [weak self] _ in
            if let content = UIPasteboard.general.string, !content.isEmpty {
                self?.showNameInputForContent(content)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showNameInputForContent(_ content: String) {
        let alert = UIAlertController(
            title: "命名",
            message: "为这段内容命名",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "名称"
            textField.text = "自定义 \(Date().formatted(date: .omitted, time: .shortened))"
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            let name = alert.textFields?[0].text ?? "自定义"
            self?.addTestCase(name: name, content: content)
        })
        
        present(alert, animated: true)
    }
    
    private func addTestCase(name: String, content: String) {
        testCases.append((name: name, content: content))
        selectedCaseIndex = testCases.count - 1
        updateCaseSelector()
        resetStreaming()
    }
    
    private func exportCurrentContent() {
        let content = testCases[selectedCaseIndex].content
        UIPasteboard.general.string = content
        
        let alert = UIAlertController(
            title: "已复制",
            message: "内容已复制到剪贴板",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func clearCustomCases() {
        // 保留前 7 个预设 case
        testCases = Array(testCases.prefix(7))
        selectedCaseIndex = min(selectedCaseIndex, testCases.count - 1)
        updateCaseSelector()
    }
    
    /// 网络接收 tick - 模拟服务端发送数据
    @objc private func networkTick() {
        guard !isPaused else { return }
        guard currentIndex < streamingBuffer.count else {
            // 网络接收完成
            networkTimer?.invalidate()
            networkTimer = nil
            return
        }
        
        // 获取基础字符数
        let config = networkSpeed.timerConfig()
        var charsToReceive = config.chars
        
        // === 不稳定网络模拟 ===
        if unstableNetworkEnabled {
            let params = networkParams
            
            // 1. 处理抖动状态（完全暂停几次）
            if jitterTicksRemaining > 0 {
                jitterTicksRemaining -= 1
                return
            }
            
            // 2. 随机触发新的抖动
            if Int.random(in: 0..<100) < params.jitterProbability {
                jitterTicksRemaining = Int.random(in: params.jitterDuration)
                return
            }
            
            // 3. 随机跳过 tick
            if Int.random(in: 0..<100) < params.skipProbability {
                skipTickCount += 1
                if skipTickCount < 2 {
                    return
                }
            }
            skipTickCount = 0
            
            // 4. 随机数据包大小波动
            let maxVariation = charsToReceive * params.variationRange
            let variation = Int.random(in: -charsToReceive...maxVariation)
            charsToReceive = max(1, charsToReceive + variation)
            
            // 5. 偶尔爆发性接收
            if Int.random(in: 0..<100) < params.burstProbability {
                charsToReceive = charsToReceive * Int.random(in: params.burstMultiplier)
            }
        }
        
        // 更新网络接收位置
        let endIndex = min(currentIndex + charsToReceive, streamingBuffer.count)
        currentIndex = endIndex
        
        // 更新积压
        updateBacklogLabel()
    }
    
    /// 渲染 tick - 消费已接收的数据
    @objc private func renderTick() {
        guard !isPaused else { return }
        
        // 计算当前积压
        let backlog = currentIndex - renderedIndex
        
        // 没有积压时跳过
        guard backlog > 0 else {
            // 检查是否全部完成
            if currentIndex >= streamingBuffer.count && renderedIndex >= streamingBuffer.count {
                streamingTimer?.invalidate()
                streamingTimer = nil
                containerView.endStreaming()
                startButton.isEnabled = false
                pauseButton.isEnabled = false
                fastForwardButton.isEnabled = false
                statusLabel.text = "渲染完成 (\(streamingBuffer.count) 字符)"
            }
            return
        }
        
        tickCounter += 1
        
        // 获取基础渲染字符数
        let config = renderSpeed.timerConfig()
        var baseChars = config.chars
        
        // === 自动加速（根据积压量调整）===
        let charsToRender: Int
        if autoAccelerateEnabled {
            let progress = Double(renderedIndex) / Double(streamingBuffer.count)
            charsToRender = accelerateAlgorithm.acceleratedChars(
                baseChars: baseChars,
                progress: progress,
                backlog: backlog
            )
        } else {
            charsToRender = baseChars
        }
        
        // 渲染不能超过已接收的数据
        let actualChars = min(charsToRender, backlog)
        let endIndex = renderedIndex + actualChars
        renderedIndex = endIndex
        
        // 渲染当前文本（增量 append，走流式 Diff + 动画）
        renderCurrentText()
        
        // 更新积压显示
        updateBacklogLabel()
        
        // 更新状态栏
        let progress = Int(Double(renderedIndex) / Double(streamingBuffer.count) * 100)
        var statusParts: [String] = []
        
        if unstableNetworkEnabled {
            statusParts.append("📶")
        } else {
            statusParts.append("🔗")
        }
        
        if autoAccelerateEnabled {
            statusParts.append("🚀")
        }
        
        statusParts.append("\(progress)%")
        statusParts.append("已渲染:\(renderedIndex)")
        statusParts.append("已接收:\(currentIndex)")
        
        statusLabel.text = statusParts.joined(separator: " ")
        
        // 更新速度标签显示实时速度
        let interval = config.interval
        let actualSpeed: String
        if interval >= 1 {
            actualSpeed = "\(actualChars)字/\(String(format: "%.1f", interval))秒"
        } else {
            let cps = Double(actualChars) / interval
            actualSpeed = String(format: "%.1f字/秒", cps)
        }
        speedLabel.text = "渲染: \(renderSpeed.description) → 实际: \(actualSpeed)"
    }
    
    private func updateBacklogLabel() {
        let backlog = currentIndex - renderedIndex
        if backlog > 50 {
            backlogLabel.text = "📦 积压: \(backlog) 字 ⚠️"
            backlogLabel.textColor = .systemRed
        } else if backlog > 20 {
            backlogLabel.text = "📦 积压: \(backlog) 字"
            backlogLabel.textColor = .systemOrange
        } else if backlog > 0 {
            backlogLabel.text = "📦 积压: \(backlog) 字"
            backlogLabel.textColor = .systemYellow
        } else {
            backlogLabel.text = "📦 积压: 0 字 ✓"
            backlogLabel.textColor = .systemGreen
        }
    }
    
    private func renderCurrentText() {
        // 使用 appendText 追加增量，走流式 Diff 路径，触发 AnimatableContent 的逐字动画
        guard lastAppendedIndex < renderedIndex else { return }
        let delta = String(streamingBuffer[lastAppendedIndex..<renderedIndex])
        containerView.appendText(delta)
        lastAppendedIndex = renderedIndex
        updateScrollViewContentSize()
    }
    
    private func updateScrollViewContentSize() {
        let contentHeight = containerView.contentHeight + 24
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: contentHeight
        )
        containerView.frame = CGRect(
            x: 12,
            y: 12,
            width: scrollView.bounds.width - 24,
            height: containerView.contentHeight
        )
    }
    
    private func scrollToBottom() {
        let bottomOffset = CGPoint(
            x: 0,
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height)
        )
        scrollView.setContentOffset(bottomOffset, animated: true)
    }
}

// MARK: - Demo Content

extension StreamingDemoViewController {
    
    static let basicDemo = """
    # V2 流式渲染演示
    
    这是一个**流式渲染**的演示，模拟 AI 回复的场景。
    
    ## 核心特性
    
    1. **逐字渐入** - 文字逐渐显示，类似打字机效果
    2. **智能积压处理** - 积压过多时自动加速
    3. **块展开动画** - 新块出现时有展开动画
    
    > 引用块也支持流式渲染
    
    感谢使用 XHSMarkdownKit V2！
    """
    
    static let codeBlockDemo = """
    # 代码块测试
    
    ## Swift 示例
    
    ```swift
    let engine = MarkdownRenderEngine.makeDefault()
    let container = MarkdownContainerView(engine: engine)
    
    container.startStreaming()
    container.appendText("New content...")
    container.endStreaming()
    ```
    
    ## Python 示例
    
    ```python
    def hello_world():
        print("Hello, World!")
        return True
    
    if __name__ == "__main__":
        hello_world()
    ```
    
    ## 长代码行测试
    
    ```swift
    let veryLongLine = "This is a very long line that should trigger horizontal scrolling in the code block view to test the scroll functionality properly"
    ```
    """
    
    static let tableDemo = """
    # 表格测试
    
    ## 基础表格
    
    | 功能 | 状态 | 备注 |
    |:-----|:----:|-----:|
    | 流式渲染 | ✅ | 完成 |
    | 代码高亮 | ⚠️ | 进行中 |
    | 图片加载 | ❌ | 待开发 |
    
    ## 带样式表格
    
    | 特性 | 描述 |
    |------|------|
    | **加粗** | 支持表格内加粗 |
    | *斜体* | 支持表格内斜体 |
    | `代码` | 支持表格内行内代码 |
    """
    
    static let nestedListDemo = """
    # 列表嵌套测试
    
    ## 无序列表嵌套
    
    - 第一层
      - 第二层
        - 第三层
          - 第四层
    
    ## 有序列表嵌套
    
    1. 第一步
       1. 子步骤 A
       2. 子步骤 B
    2. 第二步
       1. 子步骤 C
    
    ## 混合嵌套
    
    - 无序项
      1. 嵌套有序 1
      2. 嵌套有序 2
         - 再嵌套无序
    """
    
    static let blockQuoteDemo = """
    # 引用块测试
    
    ## 单层引用
    
    > 这是一段引用文字。
    > 可以有多行。
    
    ## 嵌套引用
    
    > 第一层引用
    > > 第二层引用
    > > > 第三层引用
    
    ## 引用内列表
    
    > 引用块内容：
    > - 列表项 A
    > - 列表项 B
    >   - 嵌套项
    """
    
    static let longTextDemo = """
    # 长文本测试
    
    这是一段较长的文本，用于测试流式渲染在处理大量内容时的性能表现。
    
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
    
    ## 多段落
    
    Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    
    Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.
    
    ## 分隔线
    
    ---
    
    Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
    
    ---
    
    测试完成。
    """
    
    static let mixedDemo = """
    # 混合内容测试
    
    这是一个包含**各种元素**的测试文档。
    
    ## 文本样式
    
    - **加粗文本**
    - *斜体文本*
    - ~~删除线~~
    - `行内代码`
    - [链接](https://example.com)
    
    ## 代码块
    
    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, World!")
        }
    }
    ```
    
    ## 引用
    
    > 这是一段引用
    > 包含**加粗**和*斜体*
    
    ## 表格
    
    | 名称 | 值 |
    |------|-----|
    | A | 100 |
    | B | 200 |
    
    ## 分隔线
    
    ---
    
    **测试完成** ✅
    """
}
