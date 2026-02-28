import UIKit

public final class TypingDriver: AnimationDriver {

    public var charactersPerSecond: Int
    public var onAnimationComplete: (() -> Void)?
    public var onLayoutChange: (() -> Void)?

    private var targetFragments: [RenderFragment] = []
    private var displayedLengths: [String: Int] = [:]
    private var displayedFragmentIds: [String] = []
    private var displayLink: CADisplayLink?
    private var lastTickTime: TimeInterval = 0
    private var accumulatedChars: Double = 0
    private weak var container: FragmentContaining?
    private var pendingChanges: [FragmentChange] = []

    public init(charactersPerSecond: Int = 30) {
        self.charactersPerSecond = charactersPerSecond
    }

    public func apply(changes: [FragmentChange], fragments: [RenderFragment], to container: FragmentContaining) {
        self.container = container
        self.targetFragments = fragments
        pendingChanges.append(contentsOf: changes)

        processPendingChanges()

        if displayLink == nil {
            startTicking()
        }
    }

    public func streamDidFinish() {
        // 数据流结束，不做任何事。tick 自然继续直到 allDone。
    }

    public func finishAll() {
        guard let container = container else { return }
        stopTicking()

        for fragment in targetFragments {
            if container.managedViews[fragment.fragmentId] == nil {
                ensureView(for: fragment, in: container)
            }

            let totalLen = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
            displayedLengths[fragment.fragmentId] = totalLen

            if let view = container.managedViews[fragment.fragmentId],
               let streamable = view as? StreamableContent {
                streamable.reveal(upTo: totalLen)
            }
        }

        displayedFragmentIds = targetFragments.map(\.fragmentId)
        relayout(container: container)
        onLayoutChange?()
        onAnimationComplete?()
    }

    // MARK: - Tick

    private func startTicking() {
        lastTickTime = CACurrentMediaTime()
        accumulatedChars = 0
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopTicking() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let container = container else {
            stopTicking()
            return
        }

        let now = CACurrentMediaTime()
        let delta = now - lastTickTime
        lastTickTime = now

        accumulatedChars += Double(charactersPerSecond) * delta
        let charsToReveal = Int(accumulatedChars)
        guard charsToReveal > 0 else { return }
        accumulatedChars -= Double(charsToReveal)

        var remaining = charsToReveal
        var advanced = false

        for fragment in targetFragments {
            guard remaining > 0 else { break }

            let fid = fragment.fragmentId
            let totalLen = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
            let currentLen = displayedLengths[fid] ?? 0

            if currentLen >= totalLen { continue }

            if container.managedViews[fid] == nil {
                ensureView(for: fragment, in: container)
                if !displayedFragmentIds.contains(fid) {
                    displayedFragmentIds.append(fid)
                }
            }

            let revealLen = min(remaining, totalLen - currentLen)
            let newLen = currentLen + revealLen
            displayedLengths[fid] = newLen
            remaining -= revealLen
            advanced = true

            if let view = container.managedViews[fid],
               let streamable = view as? StreamableContent {
                streamable.reveal(upTo: newLen)
            }
        }

        if advanced {
            relayout(container: container)
            onLayoutChange?()
        }

        let allDone = targetFragments.allSatisfy { fragment in
            let totalLen = (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
            return (displayedLengths[fragment.fragmentId] ?? 0) >= totalLen
        }

        if allDone {
            stopTicking()
            onAnimationComplete?()
        }
    }

    // MARK: - Process Changes

    private func processPendingChanges() {
        guard let container = container else { return }
        let changes = pendingChanges
        pendingChanges.removeAll()

        for change in changes {
            switch change {
            case .insert:
                break

            case .remove(let fragmentId, _):
                if let view = container.managedViews.removeValue(forKey: fragmentId) {
                    if let factory = targetFragments.first(where: { $0.fragmentId == fragmentId }) as? FragmentViewFactory {
                        container.viewPool.recycle(view, reuseIdentifier: factory.reuseIdentifier)
                    } else {
                        view.removeFromSuperview()
                    }
                }
                displayedLengths.removeValue(forKey: fragmentId)
                displayedFragmentIds.removeAll { $0 == fragmentId }

            case .update(_, let newFragment, _):
                if let view = container.managedViews[newFragment.fragmentId],
                   let factory = newFragment as? FragmentViewFactory {
                    factory.configure(view)
                    let currentLen = displayedLengths[newFragment.fragmentId] ?? 0
                    if let streamable = view as? StreamableContent {
                        streamable.reveal(upTo: currentLen)
                    }
                }

            case .move:
                break
            }
        }
    }

    // MARK: - Helpers

    private func ensureView(for fragment: RenderFragment, in container: FragmentContaining) {
        guard let factory = fragment as? FragmentViewFactory,
              container.managedViews[fragment.fragmentId] == nil else { return }

        let view = container.viewPool.dequeue(
            reuseIdentifier: factory.reuseIdentifier,
            factory: { factory.makeView() }
        )
        factory.configure(view)
        container.containerView.addSubview(view)
        container.managedViews[fragment.fragmentId] = view

        if let streamable = view as? StreamableContent {
            streamable.reveal(upTo: 0)
        }

        if let preferring = fragment as? TransitionPreferring,
           let transition = preferring.enterTransition {
            transition.animateIn(view: view, completion: {})
        }
    }

    private func relayout(container: FragmentContaining) {
        let width = container.containerView.bounds.width
        var y: CGFloat = 0
        let displayed = targetFragments.filter { displayedFragmentIds.contains($0.fragmentId) }

        for (i, fragment) in displayed.enumerated() {
            guard let view = container.managedViews[fragment.fragmentId] else { continue }
            let displayedLen = displayedLengths[fragment.fragmentId] ?? 0
            let height: CGFloat
            if let estimatable = view as? HeightEstimatable {
                height = estimatable.estimatedHeight(atDisplayedLength: displayedLen, maxWidth: width)
            } else {
                height = view.bounds.height
            }
            view.frame = CGRect(x: 0, y: y, width: width, height: height)
            y += height
            if i < displayed.count - 1 {
                y += fragment.spacingAfter
            }
        }
    }
}
