import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

enum SceneDebugLogger {
    enum Level {
        case compact
        case verbose
    }

    private static let envKey = "XHS_SCENE_DEBUG"
    private static let verboseEnvKey = "XHS_SCENE_DEBUG_VERBOSE"
    private static let frameEnvKey = "XHS_SCENE_FRAME_DEBUG"
    private static let defaultsKey = "xhs.scene.debug"
    private static let verboseDefaultsKey = "xhs.scene.debug.verbose"
    private static let frameDefaultsKey = "xhs.scene.debug.frame"

    static var isEnabled: Bool {
#if DEBUG
        if let envValue = ProcessInfo.processInfo.environment[envKey], envValue == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
#else
        return false
#endif
    }

    static var isVerboseEnabled: Bool {
#if DEBUG
        if let envValue = ProcessInfo.processInfo.environment[verboseEnvKey], envValue == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: verboseDefaultsKey)
#else
        return false
#endif
    }

    static func log(_ message: @autoclosure () -> String, level: Level = .compact) {
        guard isEnabled else { return }
        guard level == .compact || isVerboseEnabled else { return }
        print("[XHSSceneDebug] \(message())")
    }

    static var isFrameEnabled: Bool {
#if DEBUG
        if let envValue = ProcessInfo.processInfo.environment[frameEnvKey], envValue == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: frameDefaultsKey)
#else
        return false
#endif
    }

    static func logFrame(_ message: @autoclosure () -> String) {
        guard isFrameEnabled else { return }
        print("[XHSSceneFrame] \(message())")
    }
}

public struct RevealState {
    public let displayedUnits: Int
    public let totalUnits: Int
    public let stableUnits: Int
    public let elapsedMilliseconds: Int

    public init(
        displayedUnits: Int,
        totalUnits: Int,
        stableUnits: Int,
        elapsedMilliseconds: Int
    ) {
        self.displayedUnits = max(0, displayedUnits)
        self.totalUnits = max(0, totalUnits)
        self.stableUnits = max(0, stableUnits)
        self.elapsedMilliseconds = max(0, elapsedMilliseconds)
    }
}

public struct AppearanceProfile: Equatable {
    public let initialAlpha: CGFloat
    public let tailRampUnits: Int

    public init(initialAlpha: CGFloat = 0.25, tailRampUnits: Int = 12) {
        self.initialAlpha = max(0, min(1, initialAlpha))
        self.tailRampUnits = max(1, tailRampUnits)
    }
}

public struct AppearanceState {
    public let revealState: RevealState

    public init(revealState: RevealState) {
        self.revealState = revealState
    }
}

public protocol SceneContainerView: AnyObject {
    var sceneContentContainerView: UIView { get }
    var sceneContentInsets: UIEdgeInsets { get }
}

public protocol SceneComponent {
    var reuseIdentifier: String { get }

    func makeView() -> UIView
    func configure(view: UIView, maxWidth: CGFloat)
    func isContentEqual(to other: any SceneComponent) -> Bool
}

public protocol RevealAnimatableComponent: SceneComponent {
    var revealUnitCount: Int { get }
    func reveal(view: UIView, state: RevealState)
}

public protocol AppearanceAnimatableComponent: RevealAnimatableComponent {
    var appearanceProfile: AppearanceProfile { get }
    func applyAppearance(view: UIView, state: AppearanceState)
}

public extension NSAttributedString.Key {
    static let xhsBaseForegroundColor = NSAttributedString.Key("xhs.baseForegroundColor")
    static let xhsBlockQuoteDepth = NSAttributedString.Key("xhs.blockQuoteDepth")
    static let xhsInteractionNodeID = NSAttributedString.Key("xhs.interaction.nodeID")
    static let xhsInteractionNodeKind = NSAttributedString.Key("xhs.interaction.nodeKind")
    static let xhsInteractionStateKey = NSAttributedString.Key("xhs.interaction.stateKey")
}

public struct MergedTextSceneComponent: AppearanceAnimatableComponent {
    public let attributedText: NSAttributedString
    public let numberOfLines: Int
    public let quoteBarColor: UIColor
    public let quoteBarWidth: CGFloat
    public let quoteNestingIndent: CGFloat

    public init(
        attributedText: NSAttributedString,
        numberOfLines: Int = 0,
        quoteBarColor: UIColor = .tertiaryLabel,
        quoteBarWidth: CGFloat = 3,
        quoteNestingIndent: CGFloat = 12
    ) {
        self.attributedText = attributedText
        self.numberOfLines = numberOfLines
        self.quoteBarColor = quoteBarColor
        self.quoteBarWidth = max(1, quoteBarWidth)
        self.quoteNestingIndent = max(4, quoteNestingIndent)
    }

    public var reuseIdentifier: String { "scene.mergedText" }
    public var revealUnitCount: Int { GlyphMetric.glyphCount(in: attributedText) }
    public var appearanceProfile: AppearanceProfile { AppearanceProfile() }

    public func makeView() -> UIView {
        MergedTextSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let textView = view as? MergedTextSceneView else { return }
        textView.configure(component: self, maxWidth: maxWidth)
    }

    public func reveal(view: UIView, state: RevealState) {
        guard let textView = view as? MergedTextSceneView else { return }
        textView.render(displayedGlyphs: state.displayedUnits, stableGlyphs: state.stableUnits, appearanceProfile: nil)
    }

    public func applyAppearance(view: UIView, state: AppearanceState) {
        guard let textView = view as? MergedTextSceneView else { return }
        textView.render(
            displayedGlyphs: state.revealState.displayedUnits,
            stableGlyphs: state.revealState.stableUnits,
            appearanceProfile: appearanceProfile
        )
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? MergedTextSceneComponent else { return false }
        return attributedText.isEqual(to: rhs.attributedText)
            && numberOfLines == rhs.numberOfLines
            && quoteBarColor == rhs.quoteBarColor
            && quoteBarWidth == rhs.quoteBarWidth
            && quoteNestingIndent == rhs.quoteNestingIndent
    }
}

public struct RuleSceneComponent: SceneComponent {
    public let color: UIColor
    public let height: CGFloat
    public let verticalPadding: CGFloat
    public let leadingInset: CGFloat
    public let trailingInset: CGFloat

    public init(
        color: UIColor,
        height: CGFloat,
        verticalPadding: CGFloat = 0,
        leadingInset: CGFloat = 0,
        trailingInset: CGFloat = 0
    ) {
        self.color = color
        self.height = max(1, height)
        self.verticalPadding = max(0, verticalPadding)
        self.leadingInset = max(0, leadingInset)
        self.trailingInset = max(0, trailingInset)
    }

    public var reuseIdentifier: String { "scene.rule" }

    public func makeView() -> UIView {
        RuleSceneView()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let ruleView = view as? RuleSceneView else { return }
        ruleView.configure(
            color: color,
            lineHeight: height,
            verticalPadding: verticalPadding,
            leadingInset: leadingInset,
            trailingInset: trailingInset,
            maxWidth: maxWidth
        )
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? RuleSceneComponent else { return false }
        return color == rhs.color
            && height == rhs.height
            && verticalPadding == rhs.verticalPadding
            && leadingInset == rhs.leadingInset
            && trailingInset == rhs.trailingInset
    }
}

public struct CustomViewSceneComponent: AppearanceAnimatableComponent {
    public let reuseIdentifier: String
    public let revealUnitCount: Int
    public let signature: String
    public let appearanceProfile: AppearanceProfile
    private let make: () -> UIView
    private let configureBlock: (UIView, CGFloat) -> Void
    private let revealBlock: ((UIView, RevealState) -> Void)?
    private let appearanceBlock: ((UIView, AppearanceState) -> Void)?

    public init(
        reuseIdentifier: String,
        revealUnitCount: Int = 0,
        signature: String,
        appearanceProfile: AppearanceProfile = AppearanceProfile(),
        make: @escaping () -> UIView,
        configure: @escaping (UIView, CGFloat) -> Void,
        reveal: ((UIView, RevealState) -> Void)? = nil,
        applyAppearance: ((UIView, AppearanceState) -> Void)? = nil
    ) {
        self.reuseIdentifier = reuseIdentifier
        self.revealUnitCount = max(0, revealUnitCount)
        self.signature = signature
        self.appearanceProfile = appearanceProfile
        self.make = make
        self.configureBlock = configure
        self.revealBlock = reveal
        self.appearanceBlock = applyAppearance
    }

    public func makeView() -> UIView {
        make()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        configureBlock(view, maxWidth)
    }

    public func reveal(view: UIView, state: RevealState) {
        revealBlock?(view, state)
    }

    public func applyAppearance(view: UIView, state: AppearanceState) {
        appearanceBlock?(view, state)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? CustomViewSceneComponent else { return false }
        return reuseIdentifier == rhs.reuseIdentifier && revealUnitCount == rhs.revealUnitCount && signature == rhs.signature
    }
}

public struct RenderScene: Equatable {
    public struct Node: Equatable {
        public var id: String
        public var kind: String
        public var component: (any SceneComponent)?
        public var children: [Node]
        public var spacingAfter: CGFloat
        public var metadata: [String: MarkdownContract.Value]

        public init(
            id: String,
            kind: String,
            component: (any SceneComponent)? = nil,
            children: [Node] = [],
            spacingAfter: CGFloat = 0,
            metadata: [String: MarkdownContract.Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.component = component
            self.children = children
            if spacingAfter.isFinite {
                self.spacingAfter = max(0, spacingAfter)
            } else {
                self.spacingAfter = 0
            }
            self.metadata = metadata
        }

        public static func == (lhs: Node, rhs: Node) -> Bool {
            guard lhs.id == rhs.id,
                  lhs.kind == rhs.kind,
                  lhs.children == rhs.children,
                  lhs.spacingAfter == rhs.spacingAfter,
                  lhs.metadata == rhs.metadata else {
                return false
            }

            switch (lhs.component, rhs.component) {
            case (nil, nil):
                return true
            case let (l?, r?):
                return l.isContentEqual(to: r)
            default:
                return false
            }
        }
    }

    public var documentId: String
    public var nodes: [Node]
    public var metadata: [String: MarkdownContract.Value]

    public init(documentId: String, nodes: [Node], metadata: [String: MarkdownContract.Value] = [:]) {
        self.documentId = documentId
        self.nodes = nodes
        self.metadata = metadata
    }

    public var entityIDs: [String] {
        flattenRenderableNodes().map(\.id)
    }

    public func flattenRenderableNodes() -> [Node] {
        var result: [Node] = []

        func walk(_ node: Node) {
            if node.component != nil {
                result.append(node)
            }
            for child in node.children {
                walk(child)
            }
        }

        for node in nodes {
            walk(node)
        }

        return result
    }

    public func componentNodeByID(_ id: String) -> Node? {
        flattenRenderableNodes().first(where: { $0.id == id })
    }

    public func componentNodeIDs() -> Set<String> {
        var ids: Set<String> = []

        func walk(_ node: Node) {
            if node.component != nil {
                ids.insert(node.id)
            }
            for child in node.children {
                walk(child)
            }
        }

        for node in nodes {
            walk(node)
        }

        return ids
    }

    public static func empty(documentId: String) -> RenderScene {
        RenderScene(documentId: documentId, nodes: [])
    }
}

private final class RuleSceneView: UIView {
    private let lineView = UIView()
    private var lineHeight: CGFloat = 1
    private var verticalPadding: CGFloat = 0
    private var leadingInset: CGFloat = 0
    private var trailingInset: CGFloat = 0
    private var configuredMaxWidth: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(lineView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(
        color: UIColor,
        lineHeight: CGFloat,
        verticalPadding: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        maxWidth: CGFloat
    ) {
        self.lineHeight = max(1, lineHeight)
        self.verticalPadding = max(0, verticalPadding)
        self.leadingInset = max(0, leadingInset)
        self.trailingInset = max(0, trailingInset)
        configuredMaxWidth = max(1, maxWidth)
        lineView.backgroundColor = color
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = max(1, size.width > 0 ? size.width : configuredMaxWidth)
        return CGSize(width: width, height: ceil(lineHeight + verticalPadding * 2))
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ceil(lineHeight + verticalPadding * 2))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let widthBasis = max(1, bounds.width > 0 ? bounds.width : configuredMaxWidth)
        let lineWidth = max(0, widthBasis - leadingInset - trailingInset)
        lineView.frame = CGRect(
            x: leadingInset,
            y: verticalPadding,
            width: lineWidth,
            height: lineHeight
        )
    }
}

private final class MergedTextSceneView: UIView, UITextViewDelegate, SceneInteractionEmitting {
    private let renderTextStorage = NSTextStorage()
    private let renderLayoutManager = QuoteDecoratedLayoutManager()
    private let renderTextContainer = NSTextContainer(size: .zero)
    private let textView: UITextView

    private let measuringTextStorage = NSTextStorage()
    private let measuringLayoutManager = NSLayoutManager()
    private let measuringTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))

    private var fullText = NSAttributedString(string: "")
    private var totalGlyphCount = 0
    private var configuredMaxWidth: CGFloat = 0
    var sceneInteractionHandler: ((SceneInteractionPayload) -> Bool)?

    override init(frame: CGRect) {
        renderTextContainer.lineFragmentPadding = 0
        renderLayoutManager.addTextContainer(renderTextContainer)
        renderTextStorage.addLayoutManager(renderLayoutManager)
        textView = UITextView(frame: .zero, textContainer: renderTextContainer)

        super.init(frame: frame)

        measuringLayoutManager.addTextContainer(measuringTextContainer)
        measuringTextStorage.addLayoutManager(measuringLayoutManager)
        measuringTextContainer.lineFragmentPadding = 0

        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(component: MergedTextSceneComponent, maxWidth: CGFloat) {
        configuredMaxWidth = max(1, maxWidth)
        renderTextContainer.maximumNumberOfLines = component.numberOfLines
        renderTextContainer.lineBreakMode = component.numberOfLines > 0 ? .byTruncatingTail : .byWordWrapping
        renderLayoutManager.quoteBarColor = component.quoteBarColor
        renderLayoutManager.quoteBarWidth = component.quoteBarWidth
        renderLayoutManager.quoteNestingIndent = component.quoteNestingIndent

        fullText = GlyphMetric.annotatingBaseForegroundColor(in: component.attributedText)
        measuringTextStorage.setAttributedString(fullText)
        measuringLayoutManager.ensureLayout(for: measuringTextContainer)
        totalGlyphCount = measuringLayoutManager.numberOfGlyphs

        textView.attributedText = fullText
        invalidateIntrinsicContentSize()
    }

    func render(displayedGlyphs: Int, stableGlyphs: Int, appearanceProfile: AppearanceProfile?) {
        let clampedDisplayGlyph = min(max(0, displayedGlyphs), totalGlyphCount)
        guard clampedDisplayGlyph > 0 else {
            textView.attributedText = NSAttributedString(string: "")
            return
        }

        let displayChars = characterLength(forGlyphCount: clampedDisplayGlyph)
        guard displayChars > 0 else {
            textView.attributedText = NSAttributedString(string: "")
            return
        }

        let visibleRange = NSRange(location: 0, length: displayChars)
        let visible = NSMutableAttributedString(attributedString: fullText.attributedSubstring(from: visibleRange))

        guard let appearanceProfile else {
            textView.attributedText = visible
            return
        }

        let stableGlyph = min(max(0, stableGlyphs), clampedDisplayGlyph)
        let tailStartGlyph = min(stableGlyph, clampedDisplayGlyph)
        if tailStartGlyph >= clampedDisplayGlyph {
            textView.attributedText = visible
            return
        }

        let tailRamp = max(1, appearanceProfile.tailRampUnits)
        for glyphIndex in tailStartGlyph..<clampedDisplayGlyph {
            let glyphRange = NSRange(location: glyphIndex, length: 1)
            let characterRange = measuringLayoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            guard characterRange.length > 0 else { continue }
            guard characterRange.location < visible.length else { continue }

            let safeLength = min(characterRange.length, visible.length - characterRange.location)
            let safeRange = NSRange(location: characterRange.location, length: safeLength)
            let distanceFromTail = clampedDisplayGlyph - 1 - glyphIndex
            let normalized = min(1, CGFloat(distanceFromTail) / CGFloat(tailRamp))
            let alpha = min(1, appearanceProfile.initialAlpha + normalized * (1 - appearanceProfile.initialAlpha))

            visible.enumerateAttribute(.xhsBaseForegroundColor, in: safeRange, options: []) { value, range, _ in
                let baseColor = (value as? UIColor)
                    ?? (visible.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor)
                    ?? UIColor.label
                visible.addAttribute(.foregroundColor, value: baseColor.withAlphaComponent(alpha), range: range)
            }
        }

        textView.attributedText = visible
    }

    override var intrinsicContentSize: CGSize {
        measuredSize(for: configuredMaxWidth > 0 ? configuredMaxWidth : bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        measuredSize(for: size.width > 0 ? size.width : configuredMaxWidth)
    }

    private func characterLength(forGlyphCount glyphCount: Int) -> Int {
        let clamped = min(max(0, glyphCount), totalGlyphCount)
        guard clamped > 0 else { return 0 }
        let glyphRange = NSRange(location: 0, length: clamped)
        let charRange = measuringLayoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        return max(0, charRange.length)
    }

    private func measuredSize(for width: CGFloat) -> CGSize {
        let targetWidth = width.isFinite ? max(1, width) : 1
        let fitting = textView.sizeThatFits(
            CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
        )

        var resolvedHeight = fitting.height
        if !resolvedHeight.isFinite || resolvedHeight <= 0 {
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            let used = textView.layoutManager.usedRect(for: textView.textContainer)
            resolvedHeight = used.height + textView.textContainerInset.top + textView.textContainerInset.bottom
        }
        if !resolvedHeight.isFinite || resolvedHeight <= 0 {
            resolvedHeight = textView.font?.lineHeight ?? 1
        }

        return CGSize(
            width: targetWidth,
            height: max(1, ceil(resolvedHeight))
        )
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        var payloadData: [String: MarkdownContract.Value] = ["url": .string(URL.absoluteString)]
        if let nodeID = stringAttribute(.xhsInteractionNodeID, in: characterRange) {
            payloadData["eventNodeID"] = .string(nodeID)
        }
        if let nodeKind = stringAttribute(.xhsInteractionNodeKind, in: characterRange) {
            payloadData["eventNodeKind"] = .string(nodeKind)
        }
        if let stateKey = stringAttribute(.xhsInteractionStateKey, in: characterRange) {
            payloadData["stateKey"] = .string(stateKey)
        }

        let payload = SceneInteractionPayload(
            action: "activate",
            payload: payloadData
        )
        return sceneInteractionHandler?(payload) ?? true
    }

    private func stringAttribute(_ key: NSAttributedString.Key, in characterRange: NSRange) -> String? {
        guard let attributed = textView.attributedText else { return nil }
        guard attributed.length > 0 else { return nil }
        let clampedLocation = max(0, min(characterRange.location, attributed.length - 1))
        return attributed.attribute(key, at: clampedLocation, effectiveRange: nil) as? String
    }
}

private final class QuoteDecoratedLayoutManager: NSLayoutManager {
    var quoteBarColor: UIColor = .tertiaryLabel
    var quoteBarWidth: CGFloat = 3
    var quoteNestingIndent: CGFloat = 12

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let textStorage else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let lineLevels = quoteLineLevels(forGlyphRange: glyphsToShow, textStorage: textStorage)
        guard !lineLevels.isEmpty else { return }

        let runs = quoteBarVerticalRuns(from: lineLevels)
        guard !runs.isEmpty else { return }

        context.saveGState()
        context.setFillColor(quoteBarColor.cgColor)

        for run in runs {
            let x = origin.x + CGFloat(run.level) * quoteNestingIndent
            let barRect = CGRect(
                x: x,
                y: origin.y + run.startY,
                width: quoteBarWidth,
                height: max(1, run.endY - run.startY)
            )
            guard barRect.origin.x.isFinite,
                  barRect.origin.y.isFinite,
                  barRect.width.isFinite,
                  barRect.height.isFinite else { continue }
            context.fill(barRect)
        }

        context.restoreGState()
    }

    private struct QuoteLineLevel {
        let depth: Int
        let topY: CGFloat
        let bottomY: CGFloat
    }

    private struct QuoteBarRun {
        let level: Int
        let startY: CGFloat
        let endY: CGFloat
    }

    private func quoteLineLevels(forGlyphRange glyphRange: NSRange, textStorage: NSTextStorage) -> [QuoteLineLevel] {
        var lineLevels: [QuoteLineLevel] = []
        lineLevels.reserveCapacity(32)

        enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, lineGlyphRange, _ in
            let lineCharacterRange = self.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let depth: Int
            if let contentRange = self.trimmedLineContentRange(from: lineCharacterRange, textStorage: textStorage) {
                depth = self.maxQuoteDepth(in: contentRange, textStorage: textStorage)
            } else {
                depth = 0
            }

            lineLevels.append(
                QuoteLineLevel(
                    depth: depth,
                    topY: usedRect.minY,
                    bottomY: usedRect.maxY
                )
            )
        }

        return lineLevels
    }

    private func quoteBarVerticalRuns(from lineLevels: [QuoteLineLevel]) -> [QuoteBarRun] {
        guard !lineLevels.isEmpty else { return [] }

        var activeStarts: [CGFloat?] = []
        var activeEnds: [CGFloat?] = []
        var runs: [QuoteBarRun] = []
        runs.reserveCapacity(lineLevels.count)

        func ensureCapacity(_ depth: Int) {
            guard depth > activeStarts.count else { return }
            let delta = depth - activeStarts.count
            activeStarts.append(contentsOf: Array(repeating: nil, count: delta))
            activeEnds.append(contentsOf: Array(repeating: nil, count: delta))
        }

        func closeRuns(from level: Int) {
            guard level < activeStarts.count else { return }
            for index in level..<activeStarts.count {
                guard let start = activeStarts[index], let end = activeEnds[index] else { continue }
                runs.append(QuoteBarRun(level: index, startY: start, endY: end))
                activeStarts[index] = nil
                activeEnds[index] = nil
            }
        }

        for line in lineLevels {
            let depth = line.depth
            ensureCapacity(depth)

            if depth < activeStarts.count {
                closeRuns(from: depth)
            }

            for level in 0..<depth {
                if activeStarts[level] == nil {
                    activeStarts[level] = line.topY
                    activeEnds[level] = line.bottomY
                } else {
                    activeEnds[level] = max(activeEnds[level] ?? line.bottomY, line.bottomY)
                }
            }
        }

        closeRuns(from: 0)
        return runs
    }

    private func maxQuoteDepth(in range: NSRange, textStorage: NSTextStorage) -> Int {
        var maxDepth = 0
        textStorage.enumerateAttribute(.xhsBlockQuoteDepth, in: range, options: []) { value, _, _ in
            let depth = max(0, value as? Int ?? 0)
            maxDepth = max(maxDepth, depth)
        }
        return maxDepth
    }

    private func trimmedLineContentRange(from lineCharacterRange: NSRange, textStorage: NSTextStorage) -> NSRange? {
        guard lineCharacterRange.length > 0, textStorage.length > 0 else { return nil }

        let fullString = textStorage.string as NSString
        let lowerBound = max(0, min(lineCharacterRange.location, fullString.length))
        let upperBound = max(lowerBound, min(NSMaxRange(lineCharacterRange), fullString.length))
        guard lowerBound < upperBound else { return nil }

        var start = lowerBound
        var end = upperBound

        while start < end {
            let scalar = UnicodeScalar(fullString.character(at: start))
            if let scalar, CharacterSet.newlines.contains(scalar) {
                start += 1
                continue
            }
            break
        }

        while end > start {
            let scalar = UnicodeScalar(fullString.character(at: end - 1))
            if let scalar, CharacterSet.newlines.contains(scalar) {
                end -= 1
                continue
            }
            break
        }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }
}

private enum GlyphMetric {
    static func glyphCount(in attributedText: NSAttributedString) -> Int {
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)
        return max(0, layoutManager.numberOfGlyphs)
    }

    static func annotatingBaseForegroundColor(in attributedText: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return mutable }

        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            let color = (value as? UIColor) ?? UIColor.label
            mutable.addAttribute(.foregroundColor, value: color, range: range)
            mutable.addAttribute(.xhsBaseForegroundColor, value: color, range: range)
        }

        return mutable
    }
}
