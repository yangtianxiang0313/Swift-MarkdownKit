# Contract Rendering Guide

See also: `CAPABILITY_PLAYBOOK.md` for the full capability matrix and example map.

## 0. CocoaPods Quickstart

```ruby
# Minimal runtime (no markdown parser plugin)
pod 'XHSMarkdownKit'

# Adapter only (append on top of default runtime)
pod 'XHSMarkdownKit/AdapterMarkdownn'

# Convenience full bundle (runtime + adapter)
pod 'XHSMarkdownKit/Full'
```

## 1. Build a Kit with Explicit Adapter Installation

```swift
import XHSMarkdownCore
import XHSMarkdownAdapterMarkdownn

let registry = MarkdownContract.AdapterRegistry(
    defaultParserID: MarkdownnAdapter.parserID,
    defaultRendererID: MarkdownnAdapter.rendererID
)
MarkdownnAdapter.install(into: registry)

let kit = MarkdownContract.UniversalMarkdownKit(registry: registry)
let model = try kit.render("# Title\n\nBody")
```

Core no longer auto-registers any parser.

## 2. Register Extension Node Specs (Enum-First + Spec-Driven)

```swift
import XHSMarkdownCore

let specs = MarkdownContract.NodeSpecRegistry.core()

let calloutKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "callout"))
let tabsKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "tabs"))
let mentionKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "mention"))
let spoilerKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "spoiler"))

specs.register(.init(
    kind: calloutKind,
    role: .blockLeaf,
    childPolicy: .none,
    parseAliases: [.init(sourceKind: .directive, name: "Callout")]
))

specs.register(.init(
    kind: tabsKind,
    role: .blockContainer,
    childPolicy: .blockOnly(minChildren: 1),
    parseAliases: [.init(sourceKind: .directive, name: "Tabs")]
))

specs.register(.init(
    kind: mentionKind,
    role: .inlineLeaf,
    childPolicy: .none,
    parseAliases: [.init(sourceKind: .htmlTag, name: "mention")]
))

specs.register(.init(
    kind: spoilerKind,
    role: .inlineContainer,
    childPolicy: .inlineOnly(),
    parseAliases: [.init(sourceKind: .htmlTag, name: "spoiler")]
))
```

`TreeValidator` runs after parse and after rewrite. Unregistered or structurally invalid extension nodes fail fast.

## 3. iOS Rendering with Container

```swift
import XHSMarkdownUIKit
import XHSMarkdownAdapterMarkdownn
import XHSMarkdownCore

let registry = MarkdownContract.AdapterRegistry(
    defaultParserID: MarkdownnAdapter.parserID,
    defaultRendererID: MarkdownnAdapter.rendererID
)
let specs = MarkdownContract.NodeSpecRegistry.core()
// Register extension specs as shown in section 2 before wiring parser/renderer.
MarkdownnAdapter.install(into: registry, nodeSpecRegistry: specs)

let view = MarkdownContainerView(
    theme: .default,
    contractKit: MarkdownContract.UniversalMarkdownKit(registry: registry)
)
view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
try view.setContractMarkdown("# Hello")
```

`rewritePipeline` is optional on public entrypoints. When omitted, engine derives rewrite schema from parser/renderer `NodeSpecRegistry`.
You only pass an explicit rewrite pipeline when intentionally overriding default rewrite behavior.

## 3.1 Runtime-Managed State and Unified Event Bus

```swift
let runtime = MarkdownRuntime()
runtime.attach(to: view)

runtime.eventHandler = { event in
    print(event.action, event.payload)
    return .continueDefault
}

runtime.persistenceAdapter = yourPersistenceAdapter
runtime.dataBindingAdapter = yourDataBindingAdapter

try runtime.setInput(
    .markdown(text: "hello [link](https://example.com)", documentID: "doc.runtime")
)
```

Runtime keeps `StateSnapshot` internally and emits unified events (`activate/toggle/copy/reset/custom.*`).
External layer only handles data binding and persistence adapters.

## 4. Extension Rendering

```swift
let canonicalRegistry = MarkdownContract.CanonicalRendererRegistry.makeDefault()
let calloutKind: MarkdownContract.NodeKind = .ext(.init(namespace: "demo", name: "callout"))

canonicalRegistry.registerBlockRenderer(for: calloutKind) { node, _, _ in
    [MarkdownContract.RenderBlock(
        id: node.id,
        kind: calloutKind,
        inlines: [.init(id: "\(node.id).title", kind: .text, text: "[CALLOUT]")]
    )]
}
```

If extension renderer is missing, rendering fails with `unknown_node_kind`.

UIKit override example:

```swift
let adapter = MarkdownContract.RenderModelUIKitAdapter(
    mergePolicy: MarkdownContract.FirstBlockAnchoredMergePolicy(),
    blockMapperChain: MarkdownContract.RenderModelUIKitAdapter.makeDefaultBlockMapperChain()
)
adapter.registerBlockMapper(forExtension: "ext.demo.callout") { block, _, adapter in
    let segment = adapter.makeMergeTextSegment(
        sourceBlockID: block.id,
        kind: "callout",
        attributedText: NSAttributedString(string: "CALLOUT")
    )
    return [.mergeSegment(segment)]
}

adapter.registerInlineRenderer(forExtension: "ext.demo.mention") { span, _, _, _ in
    NSAttributedString(string: "@\(span.text)")
}
```

For complex custom UI:

```swift
adapter.registerBlockMapper(forExtension: "ext.demo.card") { block, _, adapter in
    let node = adapter.makeCustomStandaloneNode(
        id: block.id,
        kind: "custom.card",
        reuseIdentifier: "custom.card",
        signature: "v1",
        revealUnitCount: 1,
        makeView: { CustomView() }, // CustomView: UIView, RevealLayoutAnimatableView
        configure: { view, maxWidth in ... }
    )
    return [.standalone(node)]
}
```

### 4.1 Extension Onboarding Rule (No Framework Touchpoints)

To add a new extension node kind, modify only extension-layer wiring:

1. Register `NodeSpec` and parse alias in your shared `NodeSpecRegistry`.
2. Ensure parser and renderer are built with that same registry.
3. Register canonical renderer for the extension `NodeKind`.
4. Optionally register UIKit extension mapper/inline renderer.

Do not patch framework entrypoints for each new node. `UniversalMarkdownKit` and `MarkdownContractEngine` resolve rewrite pipeline automatically from parser/renderer schema when `rewritePipeline` is not provided.

## 5. Streaming

```swift
let runtime = MarkdownRuntime(streamingEngine: engine)
runtime.attach(to: view)

let ref = try runtime.startStream(documentID: "doc.streaming")
try runtime.appendStreamChunk(ref: ref, chunk: "Hello")
try runtime.appendStreamChunk(ref: ref, chunk: " world")
try runtime.finishStream(ref: ref)
```

Streaming and animation state are both persisted in `MarkdownRenderStore` (single source of truth), and `MarkdownContainerView` only consumes runtime-projected render frames.

## 6. Error Handling

Common `ModelError.code`:

- `required_field_missing`
- `unsupported_version`
- `schema_invalid`
- `unknown_node_kind`
- `invalid_style_value`

`unknown_node_kind` is expected for:
- unregistered extension node kinds
- missing extension renderers

`schema_invalid` is expected for:
- role/cardinality violations (for example block container node with inline child)
- parser/renderer `NodeSpecRegistry` mismatch when rewrite pipeline is not explicitly provided

`unknown_node_kind` is also expected for:
- extension blocks that produce no inline output and no child output in UIKit fallback (unless `uiState.collapsed == true`)

## 7. Test Commands

```bash
xcodebuild -scheme XHSMarkdownKit-Package -destination 'platform=iOS Simulator,name=iPhone 16' test
cd Example && xcodebuild -workspace ExampleApp.xcworkspace -scheme ExampleApp -destination 'generic/platform=iOS Simulator' build
```
