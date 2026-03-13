# Animation Rewrite Execution Plan

## Scope
This document defines the implementation checklist for rewriting the animation architecture in `XHSMarkdownKit` as a new design baseline (no migration compatibility required).

## Goals
- Separate responsibilities: runtime, planning, orchestration, effects, capabilities, layout.
- Remove monolithic driver behavior.
- Support deterministic orchestration: serial, parallel, barrier.
- Handle in-flight diff conflict: insert/update/remove during animation.
- Support nested container updates with tree diff + flattened apply.
- Keep scrolling behavior outside Markdown core (host app responsibility).

## Architecture Layers
1. Runtime Layer
- Owns event loop, frame clock, transaction lifecycle.
- Single-writer model on main thread.

2. Plan Layer
- Compiles `FragmentChange` + fragment tree into immutable `AnimationPlan`.
- No animation details in this layer.

3. Orchestration Layer
- Executes plan as DAG steps (`after`, `with`, `barrier`).
- Version-based cancellation and retargeting.

4. Effect Layer
- Plugin-style effects (`Typing`, `Instant`, transitions, mask-reveal extensions).
- Effects depend on capabilities, not concrete view classes.

5. Capability Layer
- View abilities exposed as protocols (text reveal, overlay host, height animation, transitions).

6. Layout Layer
- Two-phase apply: structure changes then layout convergence.
- Child-first measurement, parent-first frame commit.

## File Checklist

### Core Runtime
- `Sources/XHSMarkdownKit/Core/AnimationEngine/AnimationEngine.swift`
  - Engine protocol and default engine entry.
- `Sources/XHSMarkdownKit/Core/AnimationEngine/AnimationTransaction.swift`
  - Transaction identity, version, plan payload.
- `Sources/XHSMarkdownKit/Core/AnimationEngine/AnimationPlan.swift`
  - DAG step container.
- `Sources/XHSMarkdownKit/Core/AnimationEngine/AnimationStep.swift`
  - Step id, dependencies, targets, effect descriptor.
- `Sources/XHSMarkdownKit/Core/AnimationEngine/AnimationClock.swift`
  - Clock abstraction.
- `Sources/XHSMarkdownKit/Core/AnimationEngine/DisplayLinkClock.swift`
  - CADisplayLink clock.
- `Sources/XHSMarkdownKit/Core/AnimationEngine/MainThreadAnimationEngine.swift`
  - Single-writer executor with versioned transactions.

### Orchestration + Policy
- `Sources/XHSMarkdownKit/Core/AnimationOrchestration/ContractAnimationPlanMapper.swift`
- `Sources/XHSMarkdownKit/Core/AnimationOrchestration/ConflictPolicy.swift`
- `Sources/XHSMarkdownKit/Core/AnimationOrchestration/FragmentLifecycleController.swift`

### Effects
- `Sources/XHSMarkdownKit/Core/AnimationEffects/AnimationEffect.swift`
- `Sources/XHSMarkdownKit/Core/AnimationEffects/InstantEffect.swift`
- `Sources/XHSMarkdownKit/Core/AnimationEffects/TypingEffect.swift`
- `Sources/XHSMarkdownKit/Core/AnimationEffects/TransitionEffect.swift`
- `Sources/XHSMarkdownKit/Core/AnimationEffects/CompositeEffect.swift`

### Capabilities
- `Sources/XHSMarkdownKit/Core/AnimationCapabilities/TextRevealCapable.swift`
- `Sources/XHSMarkdownKit/Core/AnimationCapabilities/OverlayHostCapable.swift`
- `Sources/XHSMarkdownKit/Core/AnimationCapabilities/HeightAnimatableCapable.swift`
- `Sources/XHSMarkdownKit/Core/AnimationCapabilities/TransitionCapable.swift`
- `Sources/XHSMarkdownKit/Core/AnimationCapabilities/ViewCapabilityResolver.swift`

### Layout
- `Sources/XHSMarkdownKit/Core/Layout/LayoutCoordinator.swift`
- `Sources/XHSMarkdownKit/Core/Layout/DefaultLayoutCoordinator.swift`

### Public Wiring
- `Sources/XHSMarkdownKit/Public/MarkdownContainerView.swift`
  - Submit transactions to engine.
  - Emit host events: height/progress/completed.
- `Sources/XHSMarkdownKit/Markdown/Delegate/MarkdownContainerViewDelegate.swift`
  - Add progress + anchor-hint callback (optional).

## Execution Phases

### Phase 1 (Foundation)
- Implement runtime models + engine + display clock.
- Implement effect protocol and a no-op/instant effect.
- Wire container to engine with one-step plan.
- Deliverable: container can render and animate insert/update in minimal mode.

### Phase 2 (Orchestration)
- Add DAG dependencies and barrier semantics.
- Add contract plan mapping from `CompiledAnimationPlan` to runtime `AnimationPlan`.
- Add version cancellation behavior.
- Deliverable: serial/parallel step sequencing works.

### Phase 3 (Policy + Lifecycle)
- Implement state machine and conflict policy for in-flight operations.
- Deliverable: stable behavior on rapid append/remove/update.

### Phase 4 (Nested Apply)
- Child patch dispatch and event callback to parent.
- Two-phase layout convergence.
- Deliverable: nested blockquote/list updates are stable.

### Phase 5 (Extension Effects)
- Add advanced effects as plugins (segment fade, gradient mask reveal, bubble height follow).
- Keep scroll-follow in host app only.

## Acceptance Criteria
- New effect type can be added without modifying engine core or existing views.
- Serial/parallel/barrier orchestration deterministic in tests.
- In-flight insert/update/remove conflict behavior predictable by policy.
- Nested container updates converge without flashing/rebuild storms.
- Markdown core does not control external scroll view offset.

## Immediate Coding Start (this iteration)
1. Phase 1 foundational files and interfaces.
2. Basic default engine implementation with step execution.
3. Container wiring with transaction submit + callbacks.

## Implementation Status (Current)
- Done: runtime/plan/orchestration/effect/capability/layout layers are split into dedicated directories.
- Done: container animation entry is `AnimationEngine` + contract-native planning (`RenderModelDiffer` + `RenderModelAnimationCompiler` + `ContractAnimationPlanMapper`); legacy provider path removed from production pipeline.
- Done: schedule policies support `groupedByPhase` / `serialByChange` / `parallelByChange`.
- Done: submission policies support `interruptCurrent` and `queueLatest`.
- Done: queue-latest rebasing is implemented via transaction `planBuilder`; queued latest updates are rebuilt against committed state at execution time.
- Done: nested container updates apply through `childChanges` and `FragmentContaining.update(...)` path.
- Done: new effect extensions (`segmentFade`, `maskReveal`, `bubbleHeightFollow`, `streamingMask`) are plugin-registered without engine core modification.
- Done: host scroll follow remains external; Markdown exposes reveal anchor via progress (`revealedHeight`) and delegate callback.
- Done: skip-all semantics now clear queued submissions and force convergence of remaining queued transaction(s).
- Done: workspace build validation performed via `xcodebuild -workspace Example/ExampleApp.xcworkspace ...`.
