import Foundation

public final class TypingEffect: StepEffect {
    public enum FragmentAppearanceMode {
        /// New fragments start at 0 revealed length and join layout when budget reaches them.
        case sequential
        /// New fragments start fully revealed and appear immediately with existing content.
        case simultaneous
    }

    public let charactersPerSecond: Int
    public let fragmentAppearanceMode: FragmentAppearanceMode

    private var orderedFragments: [RenderFragment] = []
    private var displayedLengths: [String: Int] = [:]
    private var prepared = false
    private var completed = false
    private var accumulatedCharacters: Double = 0

    public init(
        charactersPerSecond: Int = 30,
        fragmentAppearanceMode: FragmentAppearanceMode = .sequential
    ) {
        self.charactersPerSecond = max(1, charactersPerSecond)
        self.fragmentAppearanceMode = fragmentAppearanceMode
    }

    public func prepare(step: AnimationStep, context: AnimationExecutionContext) {
        guard let container = context.container else {
            completed = true
            return
        }

        orderedFragments = step.newFragments
        displayedLengths.removeAll(keepingCapacity: true)
        accumulatedCharacters = 0
        prepared = true
        completed = false

        let oldLengthById = Dictionary(uniqueKeysWithValues: step.oldFragments.map { fragment in
            (fragment.fragmentId, totalLength(for: fragment))
        })

        for fragment in orderedFragments {
            let total = totalLength(for: fragment)
            let oldDisplayed = min(total, max(0, oldLengthById[fragment.fragmentId] ?? 0))
            let isNewFragment = oldLengthById[fragment.fragmentId] == nil
            let initialDisplayLength: Int
            if isNewFragment {
                switch fragmentAppearanceMode {
                case .sequential:
                    initialDisplayLength = 0
                case .simultaneous:
                    initialDisplayLength = total
                }
            } else {
                initialDisplayLength = oldDisplayed
            }
            guard let view = container.managedViews[fragment.fragmentId] else {
                displayedLengths[fragment.fragmentId] = initialDisplayLength
                continue
            }

            if let streamable = view as? StreamableContent {
                displayedLengths[fragment.fragmentId] = initialDisplayLength
                streamable.reveal(upTo: initialDisplayLength)
            } else {
                displayedLengths[fragment.fragmentId] = initialDisplayLength
            }
        }

        relayout(context: context)
        publishProgress(context: context)
        context.notifyLayoutChange()

        if isAllDisplayed {
            completed = true
        }
    }

    public func advance(deltaTime: TimeInterval, context: AnimationExecutionContext) -> AnimationEffectStatus {
        guard prepared else { return .running }
        if completed { return .finished }

        accumulatedCharacters += Double(charactersPerSecond) * max(0, deltaTime)
        let budget = Int(accumulatedCharacters)
        guard budget > 0 else { return .running }

        accumulatedCharacters -= Double(budget)
        var remaining = budget
        var didReveal = false

        guard let container = context.container else {
            completed = true
            return .finished
        }

        for fragment in orderedFragments {
            guard remaining > 0 else { break }

            let fragmentId = fragment.fragmentId
            let total = totalLength(for: fragment)
            let current = displayedLengths[fragmentId] ?? 0
            if current >= total { continue }

            let revealCount = min(remaining, total - current)
            let newLength = current + revealCount
            displayedLengths[fragmentId] = newLength
            remaining -= revealCount

            if let view = container.managedViews[fragmentId],
               let streamable = view as? StreamableContent {
                streamable.reveal(upTo: newLength)
            }

            didReveal = true
        }

        if didReveal {
            relayout(context: context)
            publishProgress(context: context)
            context.notifyLayoutChange()
        }

        if isAllDisplayed {
            completed = true
            return .finished
        }

        return .running
    }

    public func finish(context: AnimationExecutionContext) {
        guard let container = context.container else {
            completed = true
            return
        }

        for fragment in orderedFragments {
            let total = totalLength(for: fragment)
            displayedLengths[fragment.fragmentId] = total
            if let view = container.managedViews[fragment.fragmentId],
               let streamable = view as? StreamableContent {
                streamable.reveal(upTo: total)
            }
        }

        relayout(context: context)
        publishProgress(context: context)
        context.notifyLayoutChange()
        completed = true
    }

    public func cancel(context: AnimationExecutionContext) {
        finish(context: context)
    }

    // MARK: - Helpers

    private var isAllDisplayed: Bool {
        orderedFragments.allSatisfy { fragment in
            let total = totalLength(for: fragment)
            return (displayedLengths[fragment.fragmentId] ?? 0) >= total
        }
    }

    private func totalLength(for fragment: RenderFragment) -> Int {
        (fragment as? ProgressivelyRevealable)?.totalContentLength ?? 1
    }

    private func relayout(context: AnimationExecutionContext) {
        guard let container = context.container else { return }

        context.layoutCoordinator.relayout(
            fragments: orderedFragments,
            in: container,
            displayedLengthProvider: { fragment in
                displayedLengths[fragment.fragmentId] ?? totalLength(for: fragment)
            }
        )
    }

    private func publishProgress(context: AnimationExecutionContext) {
        let totalChars = orderedFragments.reduce(0) { partial, fragment in
            partial + totalLength(for: fragment)
        }
        let displayedChars = orderedFragments.reduce(0) { partial, fragment in
            partial + (displayedLengths[fragment.fragmentId] ?? totalLength(for: fragment))
        }

        context.setValue(totalChars, for: .totalCharacters)
        context.setValue(displayedChars, for: .displayedCharacters)
        context.setValue(currentRevealedHeight(context: context), for: .revealedHeight)
        context.setValue(displayedLengths, for: .displayedLengthsByFragment)
    }

    private func currentRevealedHeight(context: AnimationExecutionContext) -> CGFloat {
        guard let container = context.container else { return 0 }

        let width = container.containerView.bounds.width
        var totalHeight: CGFloat = 0

        for (index, fragment) in orderedFragments.enumerated() {
            guard let view = container.managedViews[fragment.fragmentId] else { continue }

            if let estimatable = view as? HeightEstimatable {
                let displayed = displayedLengths[fragment.fragmentId] ?? totalLength(for: fragment)
                totalHeight += estimatable.estimatedHeight(atDisplayedLength: displayed, maxWidth: width)
            } else {
                totalHeight += view.bounds.height
            }

            if index < orderedFragments.count - 1 {
                totalHeight += fragment.spacingAfter
            }
        }

        return totalHeight
    }
}
