# XHSMarkdownKit Architecture (v2)

## Goals

- Model-first markdown system with a stable cross-platform contract.
- Core layer has zero UIKit/XYMarkdown dependency.
- Parser/renderer adapters are explicit; no hidden default parser in core.
- iOS runtime renders `RenderModel -> RenderScene` and animates at scene step level.

## Module Topology

- `XHSMarkdownCore`
  - Canonical AST, RenderModel, animation DTO, rewrite pipeline, diff, errors.
  - Parser protocol (`MarkdownContractParser`) and engine (`MarkdownContractEngine`).
  - No `UIKit`, no `XYMarkdown` import.
- `XHSMarkdownAdapterMarkdownn`
  - `XYMarkdownContractParser` and `MarkdownnAdapter`.
  - Explicitly installs markdownn parser/renderer IDs into registry.
- `XHSMarkdownUIKit`
  - `RenderModelUIKitAdapter` (model -> scene), `MarkdownContainerView`, scene diff/apply, animation engine/effects.
  - Custom block/inline UI override API.
- `XHSMarkdownKit`
  - Default facade re-exporting `XHSMarkdownCore + XHSMarkdownUIKit` only.
- `XHSMarkdownKitMarkdownn`
  - Optional facade that additionally re-exports `XHSMarkdownAdapterMarkdownn`.

## Distribution Matrix

| Distribution | Entry | Includes | XYMarkdown Default |
| --- | --- | --- | --- |
| SPM | `XHSMarkdownKit` | `Core + UIKit` | No |
| SPM | `XHSMarkdownKitMarkdownn` | `Core + UIKit + AdapterMarkdownn` | Yes |
| CocoaPods | `pod 'XHSMarkdownKit'` | `UIKit` (+ `Core` via dependency) | No |
| CocoaPods | `pod 'XHSMarkdownKit/AdapterMarkdownn'` | Adapter only (requires default chain) | Yes |
| CocoaPods | `pod 'XHSMarkdownKit/Full'` | `UIKit + AdapterMarkdownn` | Yes |

## End-to-End Pipeline

1. Markdown text -> parser adapter -> `CanonicalDocument`.
2. Rewrite pipeline transforms canonical nodes.
3. Canonical renderer outputs `RenderModel`.
4. UIKit adapter converts `RenderModel` to `RenderScene` (stable node IDs).
5. Scene differ computes `SceneDiff` (`insert/remove/update/move`).
6. Contract timeline compiles/mapping -> `AnimationPlan` (scene steps).
7. Animation engine applies step effects and commits snapshots to container.

## Contract Rules

- All top-level DTOs carry `schemaVersion` (current: `1`).
- Unknown JSON fields are preserved.
- Unknown enum values degrade to custom/unknown path.
- Model layer forbids platform-specific types (`UIColor`, `UIFont`, etc.).
- Colors in contract use `ColorValue` (token/hex/rgba/appearance), not UIKit types.

## Custom Node Strategy

- Directive and HTML tag both map to `customElement`.
- `source.sourceKind` distinguishes origin:
  - `directive`
  - `htmlTag`
- Custom rendering:
  - Block: `registerBlockRenderer(forCustomElement:)`
  - Inline: `registerInlineRenderer(forCustomElement:)`

## Animation Strategy

- Execution unit is scene step driven by `SceneDiff`.
- Step payload: `entityIDs + fromScene + toScene + effectKey + dependencies`.
- Scheduling modes:
  - `groupedByPhase`
  - `serialByChange`
  - `parallel`
- Streaming updates continuously append text, generate model diff/plan, and animate incremental scene states.

## Validation Gates

- `xcodebuild -scheme XHSMarkdownKit-Package -destination 'platform=iOS Simulator,name=iPhone 16' test`
- `cd Example && xcodebuild -workspace ExampleApp.xcworkspace -scheme ExampleApp -destination 'generic/platform=iOS Simulator' build`
- Symbol scan must not contain legacy runtime symbols in the active chain.
