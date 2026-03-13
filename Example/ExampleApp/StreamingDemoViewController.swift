import UIKit
import XHSMarkdownKit

/// 流式渲染演示页面
/// 支持选择渲染内容、滚动跟随、参数配置、自定义内容
class StreamingDemoViewController: UIViewController {
    
    // MARK: - UI Components
    
    /// 流式内容 ScrollView（外层可见区域高度由约束固定）
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = UIColor.systemGray6
        sv.layer.cornerRadius = 12
        sv.alwaysBounceVertical = true
        return sv
    }()
    
    /// 配置区域包装（可滚动，避免内容过多时挤压展示区）
    private lazy var configAreaScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = true
        sv.alwaysBounceVertical = false
        return sv
    }()
    
    /// 是否启用逐字动画（否则即时显示）
    private var animationEnabled = true
    
    /// 容器视图（由 makeContainerView 创建，切换动画开关时重建）
    private var _containerView: MarkdownContainerView!
    private var containerView: MarkdownContainerView { _containerView }
    
    private func makeContainerView() -> MarkdownContainerView {
        let view = MarkdownContainerView()
        applyAnimationConfig(to: view)
        view.delegate = self
        return view
    }

    private func currentPreset() -> MarkdownAnimationPreset {
        switch animationPresetMode {
        case .instant:
            return .instant
        case .typing:
            return .typing(charactersPerSecond: typingCharactersPerSecond)
        case .streamingMask:
            return .streamingMask(charactersPerSecond: typingCharactersPerSecond)
        }
    }

    private func applyAnimationConfig(to view: MarkdownContainerView) {
        if animationEnabled {
            view.setAnimationPreset(currentPreset())
        } else {
            view.setAnimationPreset(.instant)
        }
        view.typingCharactersPerSecond = typingCharactersPerSecond
        view.animationSchedulingMode = schedulingMode
        view.animationSubmissionMode = submitMode
    }
    
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
        label.text = "渲染: 1.0秒/次(全部)"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()
    
    /// 渲染速度滑块（0-100：0~8=burst，8~100=渐进加速）
    private lazy var speedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 4  // 默认 burst 模式
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
    
    /// 逐字动画开关
    private lazy var animationSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        sw.onTintColor = .systemPurple
        sw.addTarget(self, action: #selector(animationSwitchChanged), for: .valueChanged)
        return sw
    }()
    
    /// 逐字动画标签
    private lazy var animationLabel: UILabel = {
        let label = UILabel()
        label.text = "✨ 逐字动画: 开"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemPurple
        return label
    }()

    /// 动画预设控制（即时/打字/遮罩）
    private lazy var animationPresetControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["即时", "打字", "遮罩"])
        control.selectedSegmentIndex = 1
        control.selectedSegmentTintColor = .systemPurple.withAlphaComponent(0.2)
        control.addTarget(self, action: #selector(animationPresetChanged), for: .valueChanged)
        return control
    }()

    /// 打字速度标签
    private lazy var typingSpeedLabel: UILabel = {
        let label = UILabel()
        label.text = "打字速度: 30 字/秒"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    /// 打字速度滑块
    private lazy var typingSpeedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 5
        slider.maximumValue = 180
        slider.value = 30
        slider.minimumTrackTintColor = .systemPurple
        slider.addTarget(self, action: #selector(typingSpeedChanged), for: .valueChanged)
        return slider
    }()

    /// 调度模式（phase/serial/parallel）
    private lazy var schedulingControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Phase", "Serial", "Parallel"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .systemIndigo.withAlphaComponent(0.2)
        control.addTarget(self, action: #selector(schedulingModeChanged), for: .valueChanged)
        return control
    }()

    /// 提交策略（中断/排队）
    private lazy var submitModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Interrupt", "Queue"])
        control.selectedSegmentIndex = 1
        control.selectedSegmentTintColor = .systemTeal.withAlphaComponent(0.2)
        control.addTarget(self, action: #selector(submitModeChanged), for: .valueChanged)
        return control
    }()

    /// 交付模式（双阶段 or SSE 直推）
    private lazy var deliveryModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["双阶段", "SSE直推"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .systemGreen.withAlphaComponent(0.2)
        control.addTarget(self, action: #selector(deliveryModeChanged), for: .valueChanged)
        return control
    }()

    /// 渲染链路（contract）
    private lazy var renderPathControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Contract"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .systemBrown.withAlphaComponent(0.2)
        control.addTarget(self, action: #selector(renderPathChanged), for: .valueChanged)
        return control
    }()

    /// 首包延迟标签
    private lazy var firstByteDelayLabel: UILabel = {
        let label = UILabel()
        label.text = "首包延迟: 0 ms"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    /// 首包延迟滑块（0~3s）
    private lazy var firstByteDelaySlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 3000
        slider.value = 0
        slider.minimumTrackTintColor = .systemGreen
        slider.addTarget(self, action: #selector(firstByteDelayChanged), for: .valueChanged)
        return slider
    }()

    /// 网络包倍率标签
    private lazy var packetScaleLabel: UILabel = {
        let label = UILabel()
        label.text = "数据包倍率: x1"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    /// 网络包倍率滑块（1x~8x）
    private lazy var packetScaleSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 8
        slider.value = 1
        slider.minimumTrackTintColor = .systemGreen
        slider.addTarget(self, action: #selector(packetScaleChanged), for: .valueChanged)
        return slider
    }()

    /// 动画链路配置摘要
    private lazy var pipelineConfigLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.text = ""
        return label
    }()

    /// 实时速率监控
    private lazy var throughputLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = ""
        return label
    }()

    /// 速度模型解释
    private lazy var speedModelLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = ""
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
    private var hasCompletedStreaming = false

    private enum RenderPath: Int {
        case contract = 0
    }

    private enum DeliveryMode: Int {
        case twoStage = 0
        case sseDirect = 1
    }

    private enum AnimationPresetMode: Int {
        case instant = 0
        case typing = 1
        case streamingMask = 2
    }

    private var deliveryMode: DeliveryMode = .twoStage
    private var animationPresetMode: AnimationPresetMode = .typing
    private var typingCharactersPerSecond: Int = 30
    private var schedulingMode: AnimationSchedulingMode = .groupedByPhase
    private var submitMode: AnimationSubmitMode = .queueLatest

    private var firstByteDelay: TimeInterval = 0
    private var packetScale: Int = 1
    private var streamStartTime: Date?
    private var observedNetworkCPS: Double = 0
    private var observedRenderCPS: Double = 0
    private var renderPath: RenderPath = .contract
    private var lastContractUpdateSequence: Int = 0
    
    /// 流式展示区域最大高度（只增不减，避免下方展开时压缩）
    
    /// 当前选中的 case 索引
    private var selectedCaseIndex = 0
    
    // MARK: - 速度配置
    
    /// 渲染速度配置（默认 burst 模式：每 1 秒一次性塞入全部积压，便于观察 Markdown 内打字机动画）
    private var renderSpeed: SpeedConfig = .burstEvery(interval: 1.0)
    
    /// 网络接收速度配置（模拟服务端推送节奏）
    private var networkSpeed: SpeedConfig = .charsPerSecond(20)
    
    /// 速度配置枚举
    private enum SpeedConfig {
        case burstEvery(interval: TimeInterval)                     // 每 N 秒一次性塞入全部积压（便于观察动画）
        case charsPerInterval(chars: Int, interval: TimeInterval)  // N字/间隔
        case charsPerSecond(Int)                                    // N字/秒
        case charsPerFrame(Int)                                     // N字/帧（高速模式）
        
        var description: String {
            switch self {
            case .burstEvery(let interval):
                return String(format: "%.1f秒/次(全部)", interval)
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
            case .burstEvery(let interval):
                return (interval, 99999, false)  // 每 N 秒，一次消费全部积压
            case .charsPerInterval(let chars, let interval):
                return (interval, chars, false)
            case .charsPerSecond(let n):
                if n <= 10 {
                    return (1.0 / Double(n), 1, false)
                } else {
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
        typingSpeedChanged()
        firstByteDelayChanged()
        packetScaleChanged()
        deliveryModeChanged()
        updateAutoAccelerateLabel()
        updateNetworkQualityLabel()
        updateBacklogLabel()
        updatePipelineConfigLabel()
        updateThroughputLabel()
        updateSpeedModelLabel()
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
        
        let streamSectionLabel = UILabel()
        streamSectionLabel.text = "流式展示区"
        streamSectionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        streamSectionLabel.textColor = .secondaryLabel
        
        _containerView = makeContainerView()
        
        view.addSubview(caseSelector)
        view.addSubview(streamSectionLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = true
        
        let configContainer = UIView()
        configContainer.addSubview(configStack)
        configContainer.addSubview(controlStack)
        configContainer.addSubview(statusLabel)
        configAreaScrollView.addSubview(configContainer)
        view.addSubview(configAreaScrollView)
        
        // 配置区域标题
        let configTitleLabel = UILabel()
        configTitleLabel.text = "参数配置"
        configTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        configTitleLabel.textColor = .label
        
        // 配置行
        let animationRow = createRow(label: "逐字动画", control: animationSwitch)
        let animationPresetRow = createRow(label: "动画预设", control: animationPresetControl)
        let typingSpeedRow = createRow(label: "打字速度", control: typingSpeedSlider)
        let schedulingRow = createRow(label: "调度模式", control: schedulingControl)
        let submitModeRow = createRow(label: "提交策略", control: submitModeControl)
        let deliveryModeRow = createRow(label: "交付模式", control: deliveryModeControl)
        let renderPathRow = createRow(label: "渲染链路", control: renderPathControl)
        let networkSpeedRow = createRow(label: "网络接收", control: networkSpeedSlider)
        let speedRow = createRow(label: "渲染速度", control: speedSlider)
        let firstByteDelayRow = createRow(label: "首包延迟", control: firstByteDelaySlider)
        let packetScaleRow = createRow(label: "包大小倍率", control: packetScaleSlider)
        let autoScrollRow = createRow(label: "滚动跟随", control: autoScrollSwitch)
        let networkModeRow = createRow(label: "网络抖动", control: networkModeSwitch)
        let autoAccelerateRow = createRowWithButton(
            label: "自动加速",
            control: autoAccelerateSwitch,
            button: algorithmButton
        )
        
        // 配置区域内容
        configStack.addArrangedSubview(configTitleLabel)
        configStack.addArrangedSubview(animationRow)
        configStack.addArrangedSubview(animationLabel)
        configStack.addArrangedSubview(animationPresetRow)
        configStack.addArrangedSubview(typingSpeedRow)
        configStack.addArrangedSubview(typingSpeedLabel)
        configStack.addArrangedSubview(schedulingRow)
        configStack.addArrangedSubview(submitModeRow)
        configStack.addArrangedSubview(deliveryModeRow)
        configStack.addArrangedSubview(renderPathRow)
        configStack.addArrangedSubview(pipelineConfigLabel)
        configStack.addArrangedSubview(networkSpeedRow)
        configStack.addArrangedSubview(networkSpeedLabel)
        configStack.addArrangedSubview(speedRow)
        configStack.addArrangedSubview(speedLabel)
        configStack.addArrangedSubview(firstByteDelayRow)
        configStack.addArrangedSubview(firstByteDelayLabel)
        configStack.addArrangedSubview(packetScaleRow)
        configStack.addArrangedSubview(packetScaleLabel)
        configStack.addArrangedSubview(backlogLabel)
        configStack.addArrangedSubview(throughputLabel)
        configStack.addArrangedSubview(speedModelLabel)
        configStack.addArrangedSubview(autoScrollRow)
        configStack.addArrangedSubview(autoAccelerateRow)
        configStack.addArrangedSubview(autoAccelerateLabel)
        configStack.addArrangedSubview(networkModeRow)
        configStack.addArrangedSubview(networkModeLabel)
        
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
        streamSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        configAreaScrollView.translatesAutoresizingMaskIntoConstraints = false
        configContainer.translatesAutoresizingMaskIntoConstraints = false
        configStack.translatesAutoresizingMaskIntoConstraints = false
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            caseSelector.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            caseSelector.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            caseSelector.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            caseSelector.heightAnchor.constraint(equalToConstant: 40),
            
            streamSectionLabel.topAnchor.constraint(equalTo: caseSelector.bottomAnchor, constant: 12),
            streamSectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            scrollView.topAnchor.constraint(equalTo: streamSectionLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.52),
            scrollView.bottomAnchor.constraint(equalTo: configAreaScrollView.topAnchor, constant: -12),
            
            configAreaScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            configAreaScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            configAreaScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            
            configContainer.topAnchor.constraint(equalTo: configAreaScrollView.contentLayoutGuide.topAnchor),
            configContainer.leadingAnchor.constraint(equalTo: configAreaScrollView.contentLayoutGuide.leadingAnchor),
            configContainer.trailingAnchor.constraint(equalTo: configAreaScrollView.contentLayoutGuide.trailingAnchor),
            configContainer.bottomAnchor.constraint(equalTo: configAreaScrollView.contentLayoutGuide.bottomAnchor),
            configContainer.widthAnchor.constraint(equalTo: configAreaScrollView.frameLayoutGuide.widthAnchor),
            
            configStack.topAnchor.constraint(equalTo: configContainer.topAnchor),
            configStack.leadingAnchor.constraint(equalTo: configContainer.leadingAnchor),
            configStack.trailingAnchor.constraint(equalTo: configContainer.trailingAnchor),
            configStack.bottomAnchor.constraint(equalTo: controlStack.topAnchor, constant: -12),
            
            controlStack.leadingAnchor.constraint(equalTo: configContainer.leadingAnchor),
            controlStack.trailingAnchor.constraint(equalTo: configContainer.trailingAnchor),
            controlStack.heightAnchor.constraint(equalToConstant: 44),
            controlStack.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),
            
            statusLabel.leadingAnchor.constraint(equalTo: configContainer.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: configContainer.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: configContainer.bottomAnchor, constant: -12)
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
        if deliveryMode == .sseDirect {
            autoAccelerateLabel.text = "🚫 自动加速: SSE直推模式下不生效"
            autoAccelerateLabel.textColor = .tertiaryLabel
        } else if autoAccelerateEnabled {
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
        
        hasCompletedStreaming = false
        lastContractUpdateSequence = 0
        containerView.resetContractStreamingSession()
        streamStartTime = Date()
        startNetworkTimer()
        if deliveryMode == .twoStage {
            startRenderTimer()
        }
        
        startButton.isEnabled = false
        pauseButton.isEnabled = true
        fastForwardButton.isEnabled = true
        
        let modeText = deliveryMode == .twoStage ? "正在流式渲染（双阶段）..." : "正在流式渲染（SSE直推）..."
        statusLabel.text = "\(modeText) [Contract]"
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
    /// 动画关闭时强制 burst 模式，否则 Demo 层渐进 append 会制造假打字机效果
    private func startRenderTimer() {
        guard deliveryMode == .twoStage else {
            streamingTimer?.invalidate()
            streamingTimer = nil
            return
        }
        let config: (interval: TimeInterval, chars: Int, useDisplayLink: Bool)
        if animationEnabled {
            config = renderSpeed.timerConfig()
        } else {
            config = SpeedConfig.burstEvery(interval: 1.0).timerConfig()
        }
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
        if deliveryMode == .sseDirect {
            streamingTimer?.invalidate()
            streamingTimer = nil
            return
        }
        if streamingTimer != nil && !isPaused {
            startRenderTimer()
        }
    }
    
    @objc private func togglePause() {
        isPaused.toggle()
        pauseButton.setTitle(isPaused ? "继续" : "暂停", for: .normal)
        pauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"), for: .normal)
        if isPaused {
            statusLabel.text = "已暂停"
        } else {
            let modeText = deliveryMode == .twoStage ? "正在流式渲染（双阶段）..." : "正在流式渲染（SSE直推）..."
            statusLabel.text = "\(modeText) [Contract]"
        }
        
        if isPaused {
            streamingTimer?.invalidate()
            streamingTimer = nil
            networkTimer?.invalidate()
            networkTimer = nil
        } else {
            startNetworkTimer()
            if deliveryMode == .twoStage {
                startRenderTimer()
            }
        }
    }
    
    @objc private func fastForward() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        networkTimer?.invalidate()
        networkTimer = nil
        
        let fullText = testCases[selectedCaseIndex].content
        do {
            try containerView.setContractMarkdown(fullText)
        } catch {
            statusLabel.text = "Contract 快进失败：\(error.localizedDescription)"
        }
        
        currentIndex = streamingBuffer.count
        renderedIndex = streamingBuffer.count
        lastAppendedIndex = renderedIndex
        
        startButton.isEnabled = false
        pauseButton.isEnabled = false
        fastForwardButton.isEnabled = false
        
        statusLabel.text = "渲染完成 (\(streamingBuffer.count) 字符)"
        updateBacklogLabel()
        observedNetworkCPS = 0
        observedRenderCPS = 0
        hasCompletedStreaming = true
        updateThroughputLabel()
        
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
        hasCompletedStreaming = false
        lastContractUpdateSequence = 0
        
        // 重置网络模拟状态
        skipTickCount = 0
        jitterTicksRemaining = 0
        tickCounter = 0
        backlogChars = 0
        
        setupStreamingBuffer()
        try? containerView.setContractMarkdown("")
        
        startButton.isEnabled = true
        pauseButton.isEnabled = false
        fastForwardButton.isEnabled = false
        pauseButton.setTitle("暂停", for: .normal)
        pauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        statusLabel.text = "点击「开始」模拟流式渲染"
        streamStartTime = nil
        observedNetworkCPS = 0
        observedRenderCPS = 0
        updateThroughputLabel()
        updatePipelineConfigLabel()
    }

    @objc private func animationPresetChanged() {
        animationPresetMode = AnimationPresetMode(rawValue: animationPresetControl.selectedSegmentIndex) ?? .typing
        applyAnimationConfig(to: containerView)
        updatePipelineConfigLabel()
        updateSpeedModelLabel()
    }

    @objc private func typingSpeedChanged() {
        typingCharactersPerSecond = max(1, Int(typingSpeedSlider.value.rounded()))
        typingSpeedLabel.text = "打字速度: \(typingCharactersPerSecond) 字/秒"
        applyAnimationConfig(to: containerView)
        updatePipelineConfigLabel()
    }

    @objc private func schedulingModeChanged() {
        switch schedulingControl.selectedSegmentIndex {
        case 1:
            schedulingMode = .serialByChange
        case 2:
            schedulingMode = .parallelByChange
        default:
            schedulingMode = .groupedByPhase
        }
        applyAnimationConfig(to: containerView)
        updatePipelineConfigLabel()
    }

    @objc private func submitModeChanged() {
        submitMode = submitModeControl.selectedSegmentIndex == 0 ? .interruptCurrent : .queueLatest
        applyAnimationConfig(to: containerView)
        updatePipelineConfigLabel()
    }

    @objc private func deliveryModeChanged() {
        deliveryMode = DeliveryMode(rawValue: deliveryModeControl.selectedSegmentIndex) ?? .twoStage
        speedSlider.isEnabled = deliveryMode == .twoStage
        speedSlider.alpha = deliveryMode == .twoStage ? 1 : 0.5
        autoAccelerateSwitch.isEnabled = deliveryMode == .twoStage
        autoAccelerateSwitch.alpha = deliveryMode == .twoStage ? 1 : 0.5
        algorithmButton.isEnabled = autoAccelerateEnabled && deliveryMode == .twoStage
        algorithmButton.alpha = (autoAccelerateEnabled && deliveryMode == .twoStage) ? 1 : 0.5
        if deliveryMode == .sseDirect {
            streamingTimer?.invalidate()
            streamingTimer = nil
        } else {
            restartRenderTimerIfNeeded()
        }
        updateAutoAccelerateLabel()
        updatePipelineConfigLabel()
        updateSpeedModelLabel()
        updateThroughputLabel()
    }

    @objc private func renderPathChanged() {
        renderPath = RenderPath(rawValue: renderPathControl.selectedSegmentIndex) ?? .contract
        lastContractUpdateSequence = 0
        updatePipelineConfigLabel()
        updateSpeedModelLabel()
        updateThroughputLabel()
        resetStreaming()
    }

    @objc private func firstByteDelayChanged() {
        firstByteDelay = TimeInterval(firstByteDelaySlider.value / 1000)
        firstByteDelayLabel.text = "首包延迟: \(Int(firstByteDelay * 1000)) ms"
        updateSpeedModelLabel()
    }

    @objc private func packetScaleChanged() {
        packetScale = max(1, Int(packetScaleSlider.value.rounded()))
        packetScaleLabel.text = "数据包倍率: x\(packetScale)"
        updateSpeedModelLabel()
    }

    private func updatePipelineConfigLabel() {
        let preset: String
        switch animationPresetMode {
        case .instant: preset = "instant"
        case .typing: preset = "typing"
        case .streamingMask: preset = "streamingMask"
        }

        let scheduling: String
        switch schedulingMode {
        case .groupedByPhase: scheduling = "groupedByPhase"
        case .serialByChange: scheduling = "serialByChange"
        case .parallelByChange: scheduling = "parallelByChange"
        }

        let submit = (submitMode == .interruptCurrent) ? "interruptCurrent" : "queueLatest"
        let enabled = animationEnabled ? "ON" : "OFF"
        let path = "contract"
        let seq = "  seq=\(lastContractUpdateSequence)"
        pipelineConfigLabel.text = "动画配置: path=\(path)  enabled=\(enabled)  preset=\(preset)  cps=\(typingCharactersPerSecond)  scheduling=\(scheduling)  submit=\(submit)\(seq)"
    }

    private func updateThroughputLabel() {
        let pathText = "Contract"
        let modeText = deliveryMode == .twoStage ? "双阶段(网络→渲染→动画)" : "SSE直推(网络→动画)"
        let renderPart: String
        if deliveryMode == .twoStage {
            renderPart = String(format: "渲染推送 %.1f cps", observedRenderCPS)
        } else {
            renderPart = "渲染速度(滑块)已禁用"
        }
        let seqPart = "  |  contractSeq: \(lastContractUpdateSequence)"
        throughputLabel.text = String(
            format: "实时速率: 网络接收 %.1f cps  |  %@  |  模式: %@  |  链路: %@%@",
            observedNetworkCPS,
            renderPart,
            modeText,
            pathText,
            seqPart
        )
    }

    private func updateSpeedModelLabel() {
        let appendAPI = "appendContractStreamChunk"
        if deliveryMode == .twoStage {
            speedModelLabel.text = "模型解释: 网络速度只影响“已接收(currentIndex)”，渲染速度只影响“\(appendAPI) 频率(renderedIndex)”，动画速度由 preset + 打字速度(cps)决定。"
        } else {
            speedModelLabel.text = "模型解释: SSE直推下网络速度直接决定 \(appendAPI) 频率；渲染速度滑块不参与，仅用于对照。首包延迟和包倍率用于模拟服务端首字延迟与 chunk 粒度。"
        }
    }
    
    @objc private func speedChanged() {
        // 滑块值 0-100：0~8=burst（便于观察动画），8~100=渐进加速
        let value = speedSlider.value
        
        if value < 8 {
            // Burst 模式：每 0.5~2 秒一次性塞入全部积压，便于观察 Markdown 内打字机动画
            let interval = 2.0 - Float(value) / 8 * 1.5  // 2秒 -> 0.5秒
            renderSpeed = .burstEvery(interval: TimeInterval(interval))
        } else if value < 18 {
            // 超慢速: 1字/3秒 ~ 1字/1秒
            let v = value - 8
            let interval = 3.0 - (Double(v) / 10.0 * 2.0)
            renderSpeed = .charsPerInterval(chars: 1, interval: interval)
        } else if value < 38 {
            // 慢速: 1字/秒 ~ 3字/秒
            let cps = 1 + Int((value - 18) / 10 * 2)
            renderSpeed = .charsPerSecond(cps)
        } else if value < 68 {
            // 正常: 3字/秒 ~ 15字/秒
            let cps = 3 + Int((value - 38) / 30 * 12)
            renderSpeed = .charsPerSecond(cps)
        } else if value < 93 {
            // 快速: 15字/秒 ~ 50字/秒
            let cps = 15 + Int((value - 68) / 25 * 35)
            renderSpeed = .charsPerSecond(cps)
        } else {
            // 极速: 2字/帧 ~ 10字/帧
            let cpf = 2 + Int((value - 93) / 7 * 8)
            renderSpeed = .charsPerFrame(cpf)
        }
        
        if deliveryMode == .twoStage {
            speedLabel.text = "渲染: \(renderSpeed.description)"
        } else {
            speedLabel.text = "渲染: \(renderSpeed.description)（SSE直推下不生效）"
        }
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
    
    @objc private func animationSwitchChanged() {
        animationEnabled = animationSwitch.isOn
        animationLabel.text = animationEnabled ? "✨ 逐字动画: 开" : "⚡ 逐字动画: 关"
        animationLabel.textColor = animationEnabled ? .systemPurple : .secondaryLabel
        updatePipelineConfigLabel()
        
        // 需重建容器以切换动画预设
        replaceContainer()
    }
    
    private func replaceContainer() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        networkTimer?.invalidate()
        networkTimer = nil
        currentIndex = 0
        renderedIndex = 0
        lastAppendedIndex = 0
        isPaused = false
        hasCompletedStreaming = false
        skipTickCount = 0
        jitterTicksRemaining = 0
        tickCounter = 0
        backlogChars = 0
        streamStartTime = nil
        observedNetworkCPS = 0
        observedRenderCPS = 0
        setupStreamingBuffer()
        
        _containerView.removeFromSuperview()
        _containerView = makeContainerView()
        scrollView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = true
        
        startButton.isEnabled = true
        pauseButton.isEnabled = false
        fastForwardButton.isEnabled = false
        statusLabel.text = "点击「开始」模拟流式渲染"
        updateScrollViewContentSize()
        updateThroughputLabel()
    }
    
    @objc private func autoAccelerateChanged() {
        autoAccelerateEnabled = autoAccelerateSwitch.isOn
        let enabled = autoAccelerateEnabled && deliveryMode == .twoStage
        algorithmButton.isEnabled = enabled
        algorithmButton.alpha = enabled ? 1.0 : 0.5
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

    private func completeStreamingIfNeeded() {
        guard !hasCompletedStreaming else { return }
        guard currentIndex >= streamingBuffer.count, renderedIndex >= streamingBuffer.count else { return }

        hasCompletedStreaming = true
        networkTimer?.invalidate()
        networkTimer = nil
        streamingTimer?.invalidate()
        streamingTimer = nil
        do {
            let update = try containerView.finishContractStreaming()
            lastContractUpdateSequence = update.sequence
        } catch {
            statusLabel.text = "Contract 收尾失败：\(error.localizedDescription)"
        }
        startButton.isEnabled = false
        pauseButton.isEnabled = false
        fastForwardButton.isEnabled = false
        statusLabel.text = animationEnabled ? "数据接收完成，动画收尾中..." : "渲染完成 (\(streamingBuffer.count) 字符)"
        updatePipelineConfigLabel()
    }
    
    /// 网络接收 tick - 模拟服务端发送数据
    @objc private func networkTick() {
        guard !isPaused else { return }
        guard currentIndex < streamingBuffer.count else {
            // 网络接收完成
            networkTimer?.invalidate()
            networkTimer = nil
            observedNetworkCPS = 0
            updateThroughputLabel()
            completeStreamingIfNeeded()
            return
        }

        if let startTime = streamStartTime,
           Date().timeIntervalSince(startTime) < firstByteDelay {
            observedNetworkCPS = 0
            updateThroughputLabel()
            return
        }
        
        // 获取基础字符数
        let config = networkSpeed.timerConfig()
        var charsToReceive = config.chars * packetScale
        
        // === 不稳定网络模拟 ===
        if unstableNetworkEnabled {
            let params = networkParams
            
            // 1. 处理抖动状态（完全暂停几次）
            if jitterTicksRemaining > 0 {
                jitterTicksRemaining -= 1
                observedNetworkCPS = 0
                updateThroughputLabel()
                return
            }
            
            // 2. 随机触发新的抖动
            if Int.random(in: 0..<100) < params.jitterProbability {
                jitterTicksRemaining = Int.random(in: params.jitterDuration)
                observedNetworkCPS = 0
                updateThroughputLabel()
                return
            }
            
            // 3. 随机跳过 tick
            if Int.random(in: 0..<100) < params.skipProbability {
                skipTickCount += 1
                if skipTickCount < 2 {
                    observedNetworkCPS = 0
                    updateThroughputLabel()
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
        
        let previousIndex = currentIndex
        // 更新网络接收位置
        let endIndex = min(currentIndex + charsToReceive, streamingBuffer.count)
        currentIndex = endIndex
        let receivedCount = max(0, currentIndex - previousIndex)
        observedNetworkCPS = config.interval > 0 ? Double(receivedCount) / config.interval : 0

        if deliveryMode == .sseDirect {
            let backlog = currentIndex - renderedIndex
            let shouldFlushInBulk = animationEnabled || backlog >= 48 || currentIndex >= streamingBuffer.count
            if shouldFlushInBulk {
                renderedIndex = currentIndex
                renderCurrentText()
                observedRenderCPS = observedNetworkCPS
            } else {
                observedRenderCPS = 0
            }
            let progress = Int(Double(max(renderedIndex, currentIndex)) / Double(max(1, streamingBuffer.count)) * 100)
            statusLabel.text = "📡 \(progress)% 直推中 已接收:\(currentIndex)"
        }
        
        // 更新积压
        updateBacklogLabel()
        updateThroughputLabel()
        completeStreamingIfNeeded()
    }
    
    /// 渲染 tick - 消费已接收的数据
    @objc private func renderTick() {
        guard !isPaused else { return }
        guard deliveryMode == .twoStage else { return }
        
        // 计算当前积压
        let backlog = currentIndex - renderedIndex
        
        // 没有积压时跳过
        guard backlog > 0 else {
            observedRenderCPS = 0
            updateThroughputLabel()
            completeStreamingIfNeeded()
            return
        }
        
        tickCounter += 1
        
        // 获取基础渲染字符数（动画关闭时强制 burst，避免 Demo 层制造假打字机效果）
        let config = animationEnabled ? renderSpeed.timerConfig() : SpeedConfig.burstEvery(interval: 1.0).timerConfig()
        var baseChars = config.chars
        
        // === 自动加速（根据积压量调整，burst 模式下 baseChars 已足够大可忽略）===
        let charsToRender: Int
        if animationEnabled, autoAccelerateEnabled {
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
        observedRenderCPS = config.interval > 0 ? Double(actualChars) / config.interval : 0
        
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
        let renderDesc = animationEnabled ? renderSpeed.description : "1.0秒/次(全部)[动画关]"
        speedLabel.text = "渲染: \(renderDesc) → 实际: \(actualSpeed)"
        updateThroughputLabel()
        completeStreamingIfNeeded()
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
        // 使用 appendContractStreamChunk 追加增量，走流式 Diff 路径，触发 AnimatableContent 的逐字动画
        guard lastAppendedIndex < renderedIndex else { return }
        let delta = String(streamingBuffer[lastAppendedIndex..<renderedIndex])
        if animationEnabled {
            do {
                let update = try containerView.appendContractStreamChunk(delta)
                lastContractUpdateSequence = update.sequence
            } catch {
                statusLabel.text = "Contract 增量失败：\(error.localizedDescription)"
            }
        } else {
            // 动画关闭时直接整段刷新，避免 Demo 侧 tick 粒度制造“假打字机”观感
            let full = String(streamingBuffer[0..<renderedIndex])
            do {
                try containerView.setContractMarkdown(full)
            } catch {
                statusLabel.text = "Contract 全量刷新失败：\(error.localizedDescription)"
            }
        }
        lastAppendedIndex = renderedIndex
        updatePipelineConfigLabel()
        updateScrollViewContentSize()
    }
    
    private func updateScrollViewContentSize() {
        let contentH = containerView.contentHeight
        let padding: CGFloat = 24
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: contentH + padding
        )
        containerView.frame = CGRect(
            x: 12,
            y: 12,
            width: scrollView.bounds.width - 24,
            height: contentH
        )
    }
    
    private func scrollToBottom() {
        let bottomOffset = CGPoint(
            x: 0,
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height)
        )
        scrollView.setContentOffset(bottomOffset, animated: true)
    }

    private func scrollToRevealAnchor(_ anchorY: CGFloat) {
        let anchorInScroll = anchorY + 12
        let followPadding: CGFloat = 28
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let targetY = max(0, min(anchorInScroll - scrollView.bounds.height + followPadding, maxOffsetY))
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
    }
}

// MARK: - MarkdownContainerViewDelegate

extension StreamingDemoViewController: MarkdownContainerViewDelegate {
    func containerView(_ view: MarkdownContainerView, didChangeContentHeight height: CGFloat) {
        updateScrollViewContentSize()
        if autoScrollEnabled {
            scrollToBottom()
        }
    }

    func containerViewDidCompleteAnimation(_ view: MarkdownContainerView) {
        guard hasCompletedStreaming else { return }
        statusLabel.text = "渲染完成 (\(streamingBuffer.count) 字符)"
    }

    func containerView(_ view: MarkdownContainerView, didUpdateRevealAnchor anchorY: CGFloat) {
        guard autoScrollEnabled else { return }
        scrollToRevealAnchor(anchorY)
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
    let container = MarkdownContainerView()
    container.setAnimationPreset(.typing(charactersPerSecond: 30))
    
    try? container.appendContractStreamChunk("New content...")
    try? container.finishContractStreaming()
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
