import UIKit

/// White gradient mask reveal effect inspired by streaming-B-span behavior.
/// The mask reveals content from top to bottom with a 3-line gradient belt,
/// using frame-rate-independent smoothing.
public final class GradientMaskRevealEffect: StepEffect {
    private let lineHeight: CGFloat
    private let fadeLines: Int
    private let followDecay: Double
    private let fadeOutDuration: TimeInterval
    private let horizontalPadding: CGFloat
    private let verticalExponent: CGFloat
    private let horizontalExponent: CGFloat
    private let verticalWeight: CGFloat
    private let horizontalWeight: CGFloat

    private var trackedFragmentIds: [String] = []
    private var totalLengthById: [String: Int] = [:]
    private var hostStates: [String: HostOverlayState] = [:]
    private var completed = false
    private var didFadeOut = false

    public init(
        lineHeight: CGFloat = 27,
        fadeLines: Int = 3,
        followDecay: Double = 0.93,
        fadeOutDuration: TimeInterval = 0.4,
        horizontalPadding: CGFloat = 24,
        verticalExponent: CGFloat = 0.7,
        horizontalExponent: CGFloat = 0.8,
        verticalWeight: CGFloat = 0.72,
        horizontalWeight: CGFloat = 0.28
    ) {
        self.lineHeight = max(1, lineHeight)
        self.fadeLines = max(1, fadeLines)
        self.followDecay = min(max(followDecay, 0.1), 0.9999)
        self.fadeOutDuration = max(0, fadeOutDuration)
        self.horizontalPadding = max(0, horizontalPadding)
        self.verticalExponent = max(0.01, verticalExponent)
        self.horizontalExponent = max(0.01, horizontalExponent)
        self.verticalWeight = max(0, verticalWeight)
        self.horizontalWeight = max(0, horizontalWeight)
    }

    public func prepare(step: AnimationStep, context: AnimationExecutionContext) {
        completed = false
        didFadeOut = false

        guard let container = context.container else {
            completed = true
            return
        }

        totalLengthById = Dictionary(uniqueKeysWithValues: step.newFragments.map { fragment in
            (fragment.fragmentId, totalLength(for: fragment))
        })
        trackedFragmentIds = resolveTrackedFragmentIds(step: step)

        // Clean stale overlays from previous steps.
        for (fragmentId, state) in hostStates where !trackedFragmentIds.contains(fragmentId) {
            state.overlayView?.removeFromSuperview()
            hostStates.removeValue(forKey: fragmentId)
        }

        for fragmentId in trackedFragmentIds {
            guard let hostView = container.managedViews[fragmentId] else { continue }

            let state = hostStates[fragmentId] ?? HostOverlayState()

            let overlay: StreamingMaskOverlayView
            if let existing = state.overlayView, existing.superview === hostView {
                overlay = existing
            } else if let existingInHost = hostView.subviews.compactMap({ $0 as? StreamingMaskOverlayView }).first {
                overlay = existingInHost
                state.smoothY = existingInHost.currentSmoothY
            } else {
                let created = StreamingMaskOverlayView()
                created.isUserInteractionEnabled = false
                created.backgroundColor = .clear
                created.frame = hostView.bounds
                created.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                hostView.addSubview(created)
                overlay = created
            }

            overlay.alpha = 1
            overlay.configure(
                fadeHeight: fadeHeight,
                horizontalPadding: horizontalPadding,
                verticalExponent: verticalExponent,
                horizontalExponent: horizontalExponent,
                verticalWeight: verticalWeight,
                horizontalWeight: horizontalWeight
            )
            overlay.update(smoothY: state.smoothY)
            state.overlayView = overlay
            hostStates[fragmentId] = state
        }

        if hostStates.isEmpty {
            completed = true
        }
    }

    public func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus {
        if completed { return .finished }

        guard let container = context.container else {
            completed = true
            return .finished
        }

        let displayedLengths = context.value(for: .displayedLengthsByFragment, as: [String: Int].self) ?? [:]
        let alpha = 1 - pow(followDecay, max(0, deltaTime) * 60)
        var hasActiveOverlay = false
        var allHostsFinished = true

        for fragmentId in trackedFragmentIds {
            guard let state = hostStates[fragmentId],
                  let hostView = container.managedViews[fragmentId],
                  let overlay = state.overlayView else {
                continue
            }
            hasActiveOverlay = true

            let displayed = max(0, displayedLengths[fragmentId] ?? 0)
            let total = totalLengthById[fragmentId] ?? 0
            let targetY = targetRevealY(
                hostView: hostView,
                displayedLength: displayed
            )

            if state.lastDisplayedLength < 0 {
                state.smoothY = targetY
            } else if displayed > state.lastDisplayedLength {
                // Typing progressed: move belt naturally with smoothing.
                state.smoothY += (targetY - state.smoothY) * CGFloat(alpha)
            } else if displayed < state.lastDisplayedLength {
                // Content truncated: snap upward to avoid stale white tail.
                state.smoothY = min(state.smoothY, targetY)
            } else {
                // Height-only changes (same typing progress): keep top of gradient stable.
                // Overlay view itself stretches via autoresizing, so lower white area grows.
            }

            state.lastDisplayedLength = displayed
            overlay.update(smoothY: state.smoothY)

            let typingFinished = total == 0 || displayed >= total
            let converged = abs(targetY - state.smoothY) < 1
            if !(typingFinished && converged) {
                allHostsFinished = false
            }
        }

        if !hasActiveOverlay {
            completed = true
            return .finished
        }

        if allHostsFinished {
            fadeOutIfNeeded()
            completed = true
            return .finished
        }

        return .running
    }

    public func streamDidFinish(context: AnimationExecutionContext) {
        // Keep natural convergence; finish condition is checked in advance.
    }

    public func finish(context: AnimationExecutionContext) {
        hostStates.values.forEach { $0.overlayView?.removeFromSuperview() }
        hostStates.removeAll()
        trackedFragmentIds.removeAll()
        totalLengthById.removeAll()
        completed = true
    }

    public func cancel(context: AnimationExecutionContext) {
        hostStates.values.forEach { $0.overlayView?.removeFromSuperview() }
        hostStates.removeAll()
        trackedFragmentIds.removeAll()
        totalLengthById.removeAll()
        completed = true
    }

    // MARK: - Helpers

    private var fadeHeight: CGFloat {
        CGFloat(fadeLines) * lineHeight
    }

    private func resolveTrackedFragmentIds(step: AnimationStep) -> [String] {
        let ids = step.changes.compactMap { change -> String? in
            switch change {
            case .insert(let fragment, _):
                return fragment.fragmentId
            case .update(_, let newFragment, _):
                return newFragment.fragmentId
            case .move(let fragmentId, _, _):
                return fragmentId
            case .remove:
                return nil
            }
        }

        if !ids.isEmpty {
            var seen = Set<String>()
            return ids.filter { seen.insert($0).inserted }
        }

        return step.newFragments.map(\.fragmentId)
    }

    private func totalLength(for fragment: RenderFragment) -> Int {
        (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
    }

    private func targetRevealY(hostView: UIView, displayedLength: Int) -> CGFloat {
        let revealedHeight: CGFloat
        if let estimatable = hostView as? HeightEstimatable {
            revealedHeight = estimatable.estimatedHeight(
                atDisplayedLength: max(0, displayedLength),
                maxWidth: max(1, hostView.bounds.width)
            )
        } else {
            revealedHeight = hostView.bounds.height
        }

        // Place the gradient belt on the reveal frontier.
        // If host height grows without typing progress, we keep this top unchanged.
        return max(0, revealedHeight - fadeHeight)
    }

    private func fadeOutIfNeeded() {
        guard !didFadeOut else { return }
        didFadeOut = true

        let overlays = hostStates.values.compactMap { $0.overlayView }
        guard !overlays.isEmpty else { return }

        if fadeOutDuration <= 0 {
            overlays.forEach { $0.removeFromSuperview() }
            return
        }

        UIView.animate(withDuration: fadeOutDuration, animations: {
            overlays.forEach { $0.alpha = 0 }
        }, completion: { _ in
            overlays.forEach { $0.removeFromSuperview() }
        })
    }
}

private final class HostOverlayState {
    weak var overlayView: StreamingMaskOverlayView?
    var smoothY: CGFloat = 0
    var lastDisplayedLength: Int = -1
}

private final class StreamingMaskOverlayView: UIView {
    private var fadeHeight: CGFloat = 81
    private var smoothY: CGFloat = 0
    private var horizontalPadding: CGFloat = 24
    private var verticalExponent: CGFloat = 0.7
    private var horizontalExponent: CGFloat = 0.8
    private var verticalWeight: CGFloat = 0.72
    private var horizontalWeight: CGFloat = 0.28

    private var gradientImage: CGImage?
    private var gradientWidth: Int = 0
    private var gradientHeight: Int = 0
    var currentSmoothY: CGFloat { smoothY }

    func configure(
        fadeHeight: CGFloat,
        horizontalPadding: CGFloat,
        verticalExponent: CGFloat,
        horizontalExponent: CGFloat,
        verticalWeight: CGFloat,
        horizontalWeight: CGFloat
    ) {
        self.fadeHeight = max(1, fadeHeight)
        self.horizontalPadding = max(0, horizontalPadding)
        self.verticalExponent = max(0.01, verticalExponent)
        self.horizontalExponent = max(0.01, horizontalExponent)
        self.verticalWeight = max(0, verticalWeight)
        self.horizontalWeight = max(0, horizontalWeight)
        rebuildGradientIfNeeded(force: true)
        setNeedsDisplay()
    }

    func update(smoothY: CGFloat) {
        self.smoothY = smoothY
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildGradientIfNeeded(force: false)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.clear(rect)

        let y = round(smoothY)

        if let gradientImage {
            let drawRect = CGRect(x: 0, y: y, width: bounds.width, height: fadeHeight)
            ctx.draw(gradientImage, in: drawRect)
        }

        let belowY = y + fadeHeight
        if belowY < bounds.height {
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: belowY, width: bounds.width, height: bounds.height - belowY))
        }
    }

    private func rebuildGradientIfNeeded(force: Bool) {
        let width = max(Int(ceil(bounds.width)), 1)
        let height = max(Int(ceil(fadeHeight)), 1)

        guard force || gradientImage == nil || gradientWidth != width || gradientHeight != height else {
            return
        }

        gradientWidth = width
        gradientHeight = height
        gradientImage = makeGradientImage(width: width, height: height)
        setNeedsDisplay()
    }

    private func makeGradientImage(width: Int, height: Int) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let yN = CGFloat(y) / CGFloat(max(1, height))

            for x in 0..<width {
                let textWidth = max(1, CGFloat(width) - horizontalPadding * 2)
                let xN = max(0, min(1, (CGFloat(x) - horizontalPadding) / textWidth))
                let weighted = pow(yN, verticalExponent) * verticalWeight + pow(xN, horizontalExponent) * horizontalWeight
                let alpha = min(1, weighted)

                let idx = (y * width + x) * 4
                pixels[idx] = 255
                pixels[idx + 1] = 255
                pixels[idx + 2] = 255
                pixels[idx + 3] = UInt8(max(0, min(255, Int(round(alpha * 255)))))
            }
        }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
