# SwiftInjection

[![CI](https://github.com/blake-osondu/SwiftInjection/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/blake-osondu/SwiftInjection/actions/workflows/ci.yml)

**Update SwiftUI screens without an App Store release.** Write a screen in ordinary SwiftUI, compile it to a JSON payload, sign it, and host it anywhere. Your app downloads it, verifies it, and renders it natively, so a fix or an experiment ships in minutes instead of waiting on review.

```
TodoScreen.swift ──compile──▶ TodoScreen.json ──sign──▶ your CDN ──▶ app: verify → cache → render
  (SwiftUI, Previews work)                     + .sig
```

```swift
// The app
RemoteInjectedScreen(loader: PayloadLoader(configuration: .init(
    url: URL(string: "https://cdn.example.com/screens/todos.json")!,
    bundled: Bundle.main.url(forResource: "todos", withExtension: "json"),
    verifier: try PayloadVerifier(base64PublicKeys: ["hlgSQnRBp9jO6Hfhgj+gIMowgLxiYqx0XERSBIe5DB4="]))))
```

## What you get

- **Native SwiftUI rendering.** About 40 components (stacks, lists, forms, navigation, inputs, …) and 60+ modifiers, with live state, bindings and actions. Not a web view.
- **Write SwiftUI, not JSON.** `swift-injection compile` turns a supported subset of SwiftUI (`@State`, models, `ForEach`, bindings, sheets, alerts, helper views) into a payload, and reports anything it can't translate at its exact line and column.
- **Safe by default.** Payloads must be signed (Ed25519) and served over HTTPS. Size and depth are bounded before decoding. Bad payloads never replace the last good one, and payloads can only call the functions your app chooses to expose. See [Security](SECURITY.md).
- **Works offline.** The app shows the last good payload from its cache, or one bundled in the app, and checks for updates in the background.
- **Escape hatches:** your own SwiftUI views as [custom components](Sources/SwiftInjection/Custom/CustomComponent.swift), Swift host functions, and JavaScript for logic the subset can't express.
- **Versioned format.** Payloads declare a schema version, and older apps skip unknown components instead of breaking.

## When to use it, and when not

**Good fits:** screens that change often or need fast fixes (onboarding, settings, promotions, forms, content and layout tweaks), and experiments that shouldn't wait on release cycles.

**Not a fit:**
- The core of your app.
- Anything that needs APIs beyond what payloads can express (use custom components for those parts).
- Changing your app's primary purpose. Apple allows downloaded interpreted code only when it doesn't (App Store Review Guideline 2.5.2). SwiftInjection is for updating screens, not for getting around review.

## Status

**0.1 (pre-release).** Payload schema `1.0`. The library API may still change before 1.0. Payloads follow [`SchemaVersion`](Sources/SwiftInjectionCore/Payload/SchemaVersion.swift): minor schema versions only add things.

Requirements: **iOS 16+** for the runtime, **macOS 13+** for the CLI and compiler. Developed and tested with Xcode 26 (Swift 6.2).

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/blake-osondu/SwiftInjection", from: "0.1.0")
```

| Product | Use it in |
|---|---|
| `SwiftInjection` | Your app: the runtime (it also re-exports `SwiftInjectionCore`) |
| `SwiftInjectionAuthoring` | The target holding your screen sources, if they call scripts |
| `SwiftInjectionCore` | Tools and servers that read or validate payloads (no UI) |
| `SwiftInjectionCompiler` | Tools that compile SwiftUI to payloads |
| `swift-injection` (executable) | `compile`, `keygen`, `sign`, `validate` |

Install the CLI from a checkout:

```sh
swift build -c release --product swift-injection
cp "$(swift build -c release --product swift-injection --show-bin-path)/swift-injection" /usr/local/bin/
```

## Quick start

**1. Write a screen** as ordinary SwiftUI:

```swift
import SwiftUI

struct Counter: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Tapped \(count) times")
                .font(.title)
            Button("Tap") { count += 1 }
                .buttonStyle(.borderedProminent)
            if count >= 10 {
                Text("Double digits!")
            }
        }
        .padding()
    }
}
```

**2. Compile it,** and serve it locally:

```sh
swift-injection compile Counter.swift --watch      # writes Counter.json on every save
python3 -m http.server 8000                        # in another terminal
```

**3. Show it in your app.** For local development, unsigned payloads over HTTP need explicit opt-outs (the simulator can reach your Mac at `localhost`):

```swift
import SwiftUI
import SwiftInjection

struct ContentView: View {
    var body: some View {
        RemoteInjectedScreen(
            loader: PayloadLoader(configuration: .init(
                url: URL(string: "http://localhost:8000/Counter.json")!,
                allowUnsigned: true,          // development only
                allowInsecureHTTP: true)),    // development only
            updatePolicy: .immediately)
    }
}
```

Edit `Counter.swift`, save, and relaunch the screen to see the change. The [examples](Examples/) include this quick start and fuller showcase apps.

**4. Ship it:** create a signing key, sign, and upload over HTTPS. See [Publishing](docs/Publishing.md):

```sh
swift-injection keygen --out release.key          # once; put the printed public key in your app
swift-injection sign Counter.json --key release.key
# upload Counter.json and Counter.json.sig together
```

## How updates reach users

`PayloadLoader` tries the network, then the last good cached payload, then the payload bundled with the app, and validates each one (signature, limits, decoding, schema version) before using it. `RemoteInjectedScreen` shows the local copy immediately and checks the network in the background. A new payload is used on the next launch (`.nextLaunch`, the default), so nobody loses what they're in the middle of, or immediately (`.immediately`).

## Extending

```swift
let store = StateStore(payload: payload)

// Your own SwiftUI views, placed by payloads with {"custom": {"name": "productCard", "props": {...}}}
StateStore.defaultComponents["productCard"] = { context in
    AnyView(ProductCard(id: context.prop("id") ?? "", onSelect: { context.send("select") }))
}

// Swift functions payloads can call with {"call": "track", "args": [...]}
store.functions["track"] = { args, _ in
    print("track:", args.map(\.displayString))
    return .null
}
```

Treat anything you expose like a public API: a payload can call it with any arguments.

## Documentation

- [Compiling SwiftUI to payloads](docs/Compiler.md): the supported Swift subset, scripts, and `swift-injection compile`
- [Publishing payloads](docs/Publishing.md): signing keys, validation, CI and key rotation
- [Payload reference](docs/PayloadReference.md): every component, modifier, expression and action, kept in sync with the code by tests
- [Security](SECURITY.md): what the SDK guarantees and what you're responsible for
- [Contributing](CONTRIBUTING.md)

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
