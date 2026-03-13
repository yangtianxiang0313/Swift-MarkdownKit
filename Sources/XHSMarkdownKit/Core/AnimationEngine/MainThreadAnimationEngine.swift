import Foundation

public final class MainThreadAnimationEngine: AnimationEngine {

    public var onAnimationComplete: (() -> Void)?
    public var onLayoutChange: (() -> Void)?
    public var onProgress: ((AnimationProgress) -> Void)?

    private let clock: AnimationClock
    private let layoutCoordinator: LayoutCoordinator
    private let lifecycleController = FragmentLifecycleController()
    private var effectFactories: [AnimationEffectKey: () -> StepEffect] = [:]

    private weak var activeContainer: FragmentContaining?
    private var activeVersion: Int = 0
    private var stepRuntimes: [AnimationStep.StepID: StepRuntime] = [:]
    private var queuedSubmission: QueuedSubmission?
    private var executionContext: AnimationExecutionContext?
    private var committedFragments: [RenderFragment] = []
    private var hasCommittedState = false
    private var activeTargetFragments: [RenderFragment] = []
    private var displayedFragments: [RenderFragment] = []

    public init(
        clock: AnimationClock = DisplayLinkClock(),
        layoutCoordinator: LayoutCoordinator = DefaultLayoutCoordinator()
    ) {
        self.clock = clock
        self.layoutCoordinator = layoutCoordinator
        self.clock.onTick = { [weak self] deltaTime in
            self?.tick(deltaTime: deltaTime)
        }

        registerEffect(.instant) { InstantEffect() }
        registerEffect(.typing) { TypingEffect() }
        registerEffect(.segmentFade) { SegmentFadeInEffect() }
        registerEffect(.maskReveal) { GradientMaskRevealEffect() }
        registerEffect(.streamingMask) {
            CompositeEffect(effects: [
                TypingEffect(),
                SegmentFadeInEffect(),
                GradientMaskRevealEffect()
            ])
        }
    }

    public func registerEffect(_ key: AnimationEffectKey, factory: @escaping () -> StepEffect) {
        effectFactories[key] = factory
    }

    public func submit(_ transaction: AnimationTransaction, to container: FragmentContaining) {
        if let existing = activeContainer, existing !== container {
            cancelActiveTransaction()
            queuedSubmission = nil
            executionContext = nil
            stepRuntimes.removeAll()
            committedFragments = []
            displayedFragments = []
            activeTargetFragments = []
            hasCommittedState = false
        }

        if transaction.version < activeVersion {
            return
        }

        if hasInFlightWork {
            switch transaction.submissionMode {
            case .interruptCurrent:
                cancelActiveTransaction()
                startTransaction(transaction, container: container)

            case .queueLatest:
                queuedSubmission = QueuedSubmission(transaction: transaction, container: container)
            }
            return
        }

        startTransaction(transaction, container: container)
    }

    public func streamDidFinish(in container: FragmentContaining) {
        guard container === activeContainer else { return }

        if let context = makeContext() {
            stepRuntimes.values
                .filter { $0.status == .running }
                .forEach { $0.effect.streamDidFinish(context: context) }
        }
    }

    public func finishAll(in container: FragmentContaining) {
        guard container === activeContainer, let context = makeContext() else { return }
        let queued = queuedSubmission
        queuedSubmission = nil

        for runtime in stepRuntimes.values {
            switch runtime.status {
            case .pending:
                runtime.status = .running
                context.layoutCoordinator.apply(step: runtime.step, to: container)
                displayedFragments = runtime.step.newFragments
                runtime.effect.prepare(step: runtime.step, context: context)
                runtime.effect.finish(context: context)
                runtime.status = .finished
            case .running:
                runtime.effect.finish(context: context)
                runtime.status = .finished
            case .finished, .cancelled:
                break
            }
        }

        context.notifyLayoutChange()
        completeActiveTransaction()

        if let queued,
           let queuedContainer = queued.container,
           queuedContainer === container {
            startTransaction(queued.transaction, container: queuedContainer)
            finishAll(in: queuedContainer)
        }
    }

    // MARK: - Internal

    private func buildRuntimes(from plan: AnimationPlan) {
        stepRuntimes.removeAll()

        for step in plan.steps {
            let factory = effectFactories[step.effectKey] ?? { InstantEffect() }
            let runtime = StepRuntime(
                step: step,
                effect: factory(),
                pendingDependencies: step.dependencies.count
            )
            stepRuntimes[step.id] = runtime
        }

        for step in plan.steps {
            for dependency in step.dependencies {
                stepRuntimes[dependency]?.dependents.insert(step.id)
            }
        }
    }

    private func drainReadySteps() {
        guard let context = makeContext() else { return }
        guard let container = activeContainer else { return }

        var didStart = true
        while didStart {
            didStart = false

            let ready = stepRuntimes.values.filter { runtime in
                runtime.status == .pending && runtime.pendingDependencies == 0
            }

            guard !ready.isEmpty else { continue }

            for runtime in ready {
                markRunningStates(for: runtime.step.changes)
                runtime.status = .running
                context.layoutCoordinator.apply(step: runtime.step, to: container)
                displayedFragments = runtime.step.newFragments
                runtime.effect.prepare(step: runtime.step, context: context)
                let status = runtime.effect.advance(deltaTime: 0, context: context)
                if status == .finished {
                    completeStep(runtime.step.id)
                }
                didStart = true
            }
        }
    }

    private func tick(deltaTime: TimeInterval) {
        guard let context = makeContext() else {
            completeActiveTransaction()
            return
        }

        let runningIds = stepRuntimes.values
            .filter { $0.status == .running }
            .map { $0.step.id }

        for stepId in runningIds {
            guard let runtime = stepRuntimes[stepId], runtime.status == .running else { continue }
            let status = runtime.effect.advance(deltaTime: deltaTime, context: context)
            if status == .finished {
                completeStep(stepId)
            }
        }

        drainReadySteps()
        emitProgress()

        if allStepsTerminal {
            completeActiveTransaction()
        }
    }

    private func completeStep(_ stepId: AnimationStep.StepID) {
        guard let runtime = stepRuntimes[stepId], runtime.status == .running else { return }

        markCompletedStates(for: runtime.step.changes)
        runtime.status = .finished

        for dependentId in runtime.dependents {
            guard let dependent = stepRuntimes[dependentId], dependent.pendingDependencies > 0 else { continue }
            dependent.pendingDependencies -= 1
        }
    }

    private func cancelActiveTransaction() {
        guard let context = makeContext() else {
            stepRuntimes.removeAll()
            committedFragments = displayedFragments
            hasCommittedState = true
            activeTargetFragments = []
            clock.stop()
            return
        }

        for runtime in stepRuntimes.values where runtime.status == .running || runtime.status == .pending {
            runtime.effect.cancel(context: context)
            runtime.status = .cancelled
        }

        committedFragments = displayedFragments
        hasCommittedState = true
        stepRuntimes.removeAll()
        executionContext = nil
        activeTargetFragments = []
        clock.stop()
    }

    private func completeActiveTransaction() {
        clock.stop()
        let hadWork = !stepRuntimes.isEmpty
        committedFragments = activeTargetFragments
        displayedFragments = activeTargetFragments
        hasCommittedState = true
        stepRuntimes.removeAll()
        executionContext = nil
        activeTargetFragments = []
        emitProgress()
        if hadWork {
            onAnimationComplete?()
        }

        if let queued = queuedSubmission {
            queuedSubmission = nil
            guard let container = queued.container else { return }
            startTransaction(queued.transaction, container: container)
        }
    }

    private func startTransaction(_ transaction: AnimationTransaction, container: FragmentContaining) {
        activeVersion = transaction.version
        activeContainer = container
        activeTargetFragments = transaction.targetFragments

        let sourceFragments = hasCommittedState ? committedFragments : transaction.sourceFragmentsHint
        displayedFragments = sourceFragments
        let plan = transaction.makePlan(from: sourceFragments)
        executionContext = AnimationExecutionContext(
            container: container,
            layoutCoordinator: layoutCoordinator,
            notifyLayoutChange: { [weak self] in
                self?.onLayoutChange?()
            }
        )

        buildRuntimes(from: plan)
        drainReadySteps()
        emitProgress()

        if hasRunningSteps {
            clock.start()
        } else if stepRuntimes.isEmpty || allStepsTerminal {
            completeActiveTransaction()
        }
    }

    private func makeContext() -> AnimationExecutionContext? {
        guard activeContainer != nil else { return nil }
        return executionContext
    }

    private func emitProgress() {
        let displayedCharacters = executionContext?.value(for: .displayedCharacters, as: Int.self)
        let totalCharacters = executionContext?.value(for: .totalCharacters, as: Int.self)
        let revealedHeight = executionContext?.value(for: .revealedHeight, as: CGFloat.self)
        let total = stepRuntimes.count
        let completed = stepRuntimes.values.filter { $0.status == .finished || $0.status == .cancelled }.count
        let progress = AnimationProgress(
            version: activeVersion,
            completedSteps: completed,
            totalSteps: total,
            isRunning: hasRunningSteps,
            displayedCharacters: displayedCharacters,
            totalCharacters: totalCharacters,
            revealedHeight: revealedHeight
        )
        onProgress?(progress)
    }

    private var hasRunningSteps: Bool {
        stepRuntimes.values.contains(where: { $0.status == .running })
    }

    private var hasInFlightWork: Bool {
        stepRuntimes.values.contains(where: { $0.status == .running || $0.status == .pending })
    }

    private var allStepsTerminal: Bool {
        stepRuntimes.values.allSatisfy { $0.status == .finished || $0.status == .cancelled }
    }

    private func markRunningStates(for changes: [FragmentChange]) {
        for change in changes {
            switch change {
            case .insert(let fragment, _):
                lifecycleController.setState(.entering, for: fragment.fragmentId)
            case .remove(let fragmentId, _):
                lifecycleController.setState(.exiting, for: fragmentId)
            case .update(_, let newFragment, _):
                lifecycleController.setState(.updating, for: newFragment.fragmentId)
            case .move(let fragmentId, _, _):
                lifecycleController.setState(.updating, for: fragmentId)
            }
        }
    }

    private func markCompletedStates(for changes: [FragmentChange]) {
        for change in changes {
            switch change {
            case .insert(let fragment, _):
                lifecycleController.setState(.active, for: fragment.fragmentId)
            case .update(_, let newFragment, _):
                lifecycleController.setState(.active, for: newFragment.fragmentId)
            case .move(let fragmentId, _, _):
                lifecycleController.setState(.active, for: fragmentId)
            case .remove(let fragmentId, _):
                lifecycleController.setState(.removed, for: fragmentId)
                lifecycleController.removeState(for: fragmentId)
            }
        }
    }
}

private final class StepRuntime {
    enum Status {
        case pending
        case running
        case finished
        case cancelled
    }

    let step: AnimationStep
    let effect: StepEffect
    var pendingDependencies: Int
    var dependents: Set<AnimationStep.StepID> = []
    var status: Status = .pending

    init(step: AnimationStep, effect: StepEffect, pendingDependencies: Int) {
        self.step = step
        self.effect = effect
        self.pendingDependencies = pendingDependencies
    }
}

private final class QueuedSubmission {
    let transaction: AnimationTransaction
    weak var container: FragmentContaining?

    init(transaction: AnimationTransaction, container: FragmentContaining) {
        self.transaction = transaction
        self.container = container
    }
}
