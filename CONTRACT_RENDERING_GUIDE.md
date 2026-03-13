# Contract Rendering Guide

This guide documents the contract-mode entry points and custom element override path.

## Goals

- Keep model layer platform-agnostic (`Value`, `StyleValue`, `ColorValue`) with no UIKit types.
- Reuse existing iOS rendering runtime through an adapter.
- Allow directive / HTML custom elements to override UI rendering without changing parser/renderer core.

## Entry Points (iOS)

`MarkdownContainerView` supports two contract paths:

- Full text render:
  - `setContractMarkdown(_:parserID:rendererID:parseOptions:rewritePipeline:renderOptions:)`
  - `setContractRenderModel(_:animationPlan:)`
- Streaming render:
  - `resetContractStreamingSession(...)`
  - `appendContractStreamChunk(_:)`
  - `finishContractStreaming()`

When contract mode is active, rendering uses `contractRenderAdapter` (`MarkdownContract.RenderModelUIKitAdapter`).

## Custom Element Override

Register custom block renderer:

```swift
view.contractRenderAdapter.registerBlockRenderer(forCustomElement: "Card") { block, context, adapter in
    // Build your own fragment(s)
    adapter.renderBlockAsDefault(block, context: context)
}
```

Resolution order inside adapter:

1. `custom:<attrs.name>`
2. block kind key (`heading`, `paragraph`, `custom`, ...)
3. default adapter renderer

Register custom inline renderer:

```swift
view.contractRenderAdapter.registerInlineRenderer(forCustomElement: "badge") { span, block, context, adapter in
    NSAttributedString(string: "[BADGE]")
}
```

## Directive / HTML Mapping

- Directive example `@Card(...) { ... }` is parsed to `customElement` with `attrs.name = "Card"`.
- HTML tag is parsed to `customElement` with `attrs.name = "<tagName>"`.
- Block-level HTML custom elements can be overridden via `forCustomElement`.
- Inline HTML tags are rendered as inline content by canonical renderer, so block override is not applied.
- Inline HTML custom elements can be overridden via `registerInlineRenderer(forCustomElement:)`.

## Animation DTO

Contract streaming returns `StreamingRenderUpdate`, including:

- `diff`: model-level diff
- `animationPlan`: contract animation DTO
- `progress`: `AnimationProgress`

`MarkdownContainerView` now consumes contract `animationPlan` during contract streaming updates through `contractAnimationPlanMapper` (default: `DefaultContractAnimationPlanMapper`), then submits mapped runtime `AnimationPlan` to the animation engine.

Default compiler phase hints:

- `phase.structure` -> `effectKey: "segmentFade"`
- `phase.content` -> `effectKey: "typing"`

You can replace the mapper:

```swift
view.contractAnimationPlanMapper = DefaultContractAnimationPlanMapper()
```
