# XHSMarkdownKit Architecture (v2)

## Goals

- Model-first markdown system with a stable cross-platform contract.
- Core layer has zero UIKit/XYMarkdown dependency.
- Parser/renderer adapters are explicit; no hidden default parser in core.
- iOS runtime renders `RenderModel -> RenderScene` and animates at scene step level.
- Node kinds are enum-first for core and spec-driven for extensions.

## Module Topology

- `XHSMarkdownCore`
  - Canonical AST, RenderModel, animation DTO, rewrite pipeline, diff, errors, node specs.
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
2. `TreeValidator` validates parse output against `NodeSpecRegistry` (strict fail).
3. Rewrite pipeline transforms canonical nodes.
   - `MarkdownContractEngine` resolves rewrite schema from parser/renderer `NodeSpecRegistry` when `rewritePipeline == nil`.
   - If parser and renderer expose different registries, engine fails fast with `schema_invalid` at `MarkdownContractEngine.rewritePipeline`.
   - Explicit rewrite pipeline still has highest priority when caller provides one.
4. `TreeValidator` validates rewritten tree again (strict fail).
5. Canonical renderer outputs `RenderModel`.
6. UIKit adapter converts `RenderModel` to `RenderScene` (stable node IDs).
7. Scene differ computes `SceneDiff` (`insert/remove/update/move`).
8. Contract timeline compiles and maps to `RenderExecutionPlan` (staged structure/content execution).
9. `RenderCommitCoordinator` executes staged updates and persists reveal progress in `MarkdownRenderStore` (keyed by `documentId + entityId`) before committing snapshots to container.

## Node Kind Model

- `NodeKind = .core(CoreNodeKind) | .ext(ExtensionNodeKind)`.
- `CoreNodeKind` keeps compile-time exhaustive switch checks in core.
- `ExtensionNodeKind` keeps extension kind identity (`ext.<namespace>.<name>`).
- `NodeKind(rawValue:)` decodes unknown values to `.ext(...)`, then structural validation decides whether it is allowed.

## NodeSpec and Tree Policy

- `NodeSpec` declares:
  - `kind`
  - `role` (`root`, `blockLeaf`, `blockContainer`, `inlineLeaf`, `inlineContainer`)
  - `childPolicy` (`allowedChildRoles + minChildren + maxChildren`)
  - `parseAliases` (`sourceKind + name` -> `NodeKind`)
- `NodeSpecRegistry` is the only source of truth for node structure contracts.
- Parser/renderer/rewrite must share the same `NodeSpecRegistry` semantics. There is no implicit fallback contract when extension schema is present.
- `TreeValidator` runs in parser/rewrite/renderer paths and throws:
  - `unknown_node_kind` for unregistered kinds
  - `schema_invalid` for child-role/cardinality violations
- Validation error includes concrete path (`root.children[0]...`) for precise failure localization.

## Contract Rules

- All top-level DTOs carry `schemaVersion` (current: `1`).
- Unknown JSON fields are preserved.
- Unknown node kinds do not silently degrade; they must be registered in `NodeSpecRegistry`.
- Model layer forbids platform-specific types (`UIColor`, `UIFont`, etc.).
- Colors in contract use `ColorValue` (token/hex/rgba/appearance), not UIKit types.

## Extension Node Strategy

- Parser resolves extension node kind by `parseAliases` in `NodeSpecRegistry`.
- Example mapping:
  - Directive `Callout` -> `ext.demo.callout` (block leaf)
  - Directive `Tabs` -> `ext.demo.tabs` (block container)
  - HTML tag `mention` -> `ext.demo.mention` (inline leaf)
  - HTML tag `spoiler` -> `ext.demo.spoiler` (inline container)
- Canonical renderer must register renderer per extension `NodeKind`; missing registration is a hard error.
- UIKit layer can override extension rendering by extension key (`registerBlockRenderer(forExtension:)`, `registerInlineRenderer(forExtension:)`).
- Adding an extension node should only require spec + parser alias + renderer/mapper registration. Framework entrypoints should not need code changes.
- UIKit extension block fallback is fail-fast: if an extension block has no inline output and no child output (and `uiState.collapsed != true`), adapter throws `unknown_node_kind` instead of silently dropping it.

## Animation Strategy

- Execution unit is staged (`structure` / `content`) and derived from contract timeline + `SceneDelta`.
- Runtime progress is tracked in `MarkdownRenderStore` keyed by `documentId + entityId`; it is not stored on views or in scene model DTOs.
- `RenderCommitCoordinator` is the single execution entry for instant and animated commits.
- Streaming updates continuously append text, generate diff + compiled plan, and animate incremental scene states.

## Validation Gates

- `xcodebuild -scheme XHSMarkdownKit-Package -destination 'platform=iOS Simulator,name=iPhone 16' test`
- `cd Example && xcodebuild -workspace ExampleApp.xcworkspace -scheme ExampleApp -destination 'generic/platform=iOS Simulator' build`
- Symbol scan must not contain legacy runtime symbols in the active chain.
