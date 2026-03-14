# Contract Rendering Guide

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

## 2. iOS Rendering with Container

```swift
import XHSMarkdownUIKit
import XHSMarkdownAdapterMarkdownn

let registry = MarkdownContract.AdapterRegistry(
    defaultParserID: MarkdownnAdapter.parserID,
    defaultRendererID: MarkdownnAdapter.rendererID
)
MarkdownnAdapter.install(into: registry)

let view = MarkdownContainerView(
    theme: .default,
    contractKit: MarkdownContract.UniversalMarkdownKit(registry: registry),
    contractStreamingEngine: MarkdownnAdapter.makeEngine()
)
view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
try view.setContractMarkdown("# Hello")
```

## 3. Custom Block/Inline UI Override

```swift
let adapter = MarkdownContract.RenderModelUIKitAdapter()

adapter.registerBlockRenderer(forCustomElement: "Card") { block, _, adapter in
    [adapter.makeTextNode(
        id: block.id,
        kind: "paragraph",
        text: NSAttributedString(string: "CARD")
    )]
}

adapter.registerInlineRenderer(forCustomElement: "badge") { span, _, _, _ in
    NSAttributedString(string: "[\(span.text)]")
}

view.contractRenderAdapter = adapter
```

For complex custom UI:

```swift
adapter.makeCustomViewNode(
    id: block.id,
    kind: "custom",
    reuseIdentifier: "custom.card",
    signature: "v1",
    revealUnitCount: 1,
    makeView: { CustomView() },
    configure: { view, maxWidth in ... },
    reveal: { view, units in ... }
)
```

## 4. Streaming

```swift
let u1 = try view.appendContractStreamChunk("Hello")
let u2 = try view.appendContractStreamChunk(" world")
let final = try view.finishContractStreaming()
```

Each update carries `model`, `diff`, and compiled contract timeline.

## 5. Error Handling

Common `ModelError.code`:

- `required_field_missing`
- `unsupported_version`
- `schema_invalid`
- `unknown_node_kind`
- `invalid_style_value`

## 6. Test Commands

```bash
xcodebuild -scheme XHSMarkdownKit-Package -destination 'platform=iOS Simulator,name=iPhone 16' test
cd Example && xcodebuild -workspace ExampleApp.xcworkspace -scheme ExampleApp -destination 'generic/platform=iOS Simulator' build
```
