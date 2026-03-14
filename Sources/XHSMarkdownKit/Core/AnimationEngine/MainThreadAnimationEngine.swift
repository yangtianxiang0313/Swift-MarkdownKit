import Foundation

public final class MainThreadAnimationEngine: AnimationEngine {
    public var onAnimationComplete: (() -> Void)?
    public var onLayoutChange: (() -> Void)?
    public var onProgress: ((AnimationProgress) -> Void)?

    private var effectFactories: [AnimationEffectKey: () -> StepEffect] = [:]
    private weak var activeHost: (any SceneAnimationHost)?
    private var activeVersion: Int = 0
    private var queued: AnimationTransaction?
    private var running = false

    public init() {
        registerEffect(.instant) { InstantEffect() }
        registerEffect(.typing) { TypingEffect() }
        registerEffect(.segmentFade) { SegmentFadeInEffect() }
        registerEffect(.maskReveal) { GradientMaskRevealEffect() }
        registerEffect(.streamingMask) {
            CompositeEffect(effects: [TypingEffect(), SegmentFadeInEffect(), GradientMaskRevealEffect()])
        }
    }

    public func registerEffect(_ key: AnimationEffectKey, factory: @escaping () -> StepEffect) {
        effectFactories[key] = factory
    }

    public func submit(_ transaction: AnimationTransaction, to host: any SceneAnimationHost) {
        if running {
            switch transaction.submissionMode {
            case .interruptCurrent:
                queued = nil
                run(transaction, on: host)
            case .queueLatest:
                queued = transaction
            }
            return
        }

        run(transaction, on: host)
    }

    public func streamDidFinish(in host: any SceneAnimationHost) {
        guard let activeHost, ObjectIdentifier(activeHost) == ObjectIdentifier(host) else { return }
    }

    public func finishAll(in host: any SceneAnimationHost) {
        guard let activeHost, ObjectIdentifier(activeHost) == ObjectIdentifier(host) else { return }
        running = false
        if let queued {
            self.queued = nil
            run(queued, on: host)
        }
    }

    private func run(_ transaction: AnimationTransaction, on host: any SceneAnimationHost) {
        running = true
        activeVersion = transaction.version
        activeHost = host

        let source = host.currentSceneSnapshot
        let plan = transaction.makePlan(from: source)
        let total = max(1, plan.steps.count)

        onProgress?(AnimationProgress(version: activeVersion, completedSteps: 0, totalSteps: total, isRunning: true))

        let orderedSteps = topologicalSteps(plan.steps)
        var completed = 0

        for step in orderedSteps {
            let factory = effectFactories[step.effectKey] ?? { InstantEffect() }
            let effect = factory()
            _ = effect.apply(step: step, host: host)
            completed += 1
            onLayoutChange?()
            onProgress?(AnimationProgress(version: activeVersion, completedSteps: completed, totalSteps: total, isRunning: completed < total))
        }

        if plan.steps.isEmpty {
            host.applySceneSnapshot(transaction.targetScene)
            onLayoutChange?()
        }

        running = false
        onAnimationComplete?()

        if let queued {
            self.queued = nil
            run(queued, on: host)
        }
    }

    private func topologicalSteps(_ steps: [AnimationStep]) -> [AnimationStep] {
        guard !steps.isEmpty else { return [] }

        let byID = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })
        var indegree = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, 0) })
        var edges: [AnimationStep.StepID: [AnimationStep.StepID]] = [:]

        for step in steps {
            for dep in step.dependencies where byID[dep] != nil {
                indegree[step.id, default: 0] += 1
                edges[dep, default: []].append(step.id)
            }
        }

        var queue = steps.map(\.id).filter { indegree[$0] == 0 }
        var result: [AnimationStep] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let step = byID[current] {
                result.append(step)
            }

            for next in edges[current] ?? [] {
                let nextValue = (indegree[next] ?? 1) - 1
                indegree[next] = nextValue
                if nextValue == 0 {
                    queue.append(next)
                }
            }
        }

        if result.count != steps.count {
            return steps
        }

        return result
    }
}
