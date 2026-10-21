# Changelog

This project follows [Semantic Versioning](https://semver.org). The payload format is versioned separately by `schemaVersion` (see `SchemaVersion`).

## [Unreleased]

Payload schema `1.1`. Runtimes accept 1.0 and 1.1 payloads; the compiler stamps each payload with the lowest schema it needs, so payloads that don't use 1.1 features still load in 0.1.0 apps.

### Added
- Modifiers (schema 1.1): `tabViewStyle` (page-style tab views with page dots), `indexViewStyle`, `aspectRatio`, and `systemFontSize` (`.font(.system(size:weight:design:))`).
- `SchemaVersion.minimum(for:)`: the lowest schema a payload needs.
- Compiler: `TabView`, `tabItem`, `tabViewStyle`, `indexViewStyle`, `animation(_:value:)`, `.font(.system(size:…))`, `aspectRatio` / `scaledToFit` / `scaledToFill`, `Color` parameters on helper views.
- `hostAction(…)` / `hostValue(…)` in `SwiftInjectionAuthoring`: call Swift functions the app registers, without JavaScript. `swift-injection compile` lists the host functions a screen needs.
- Compiler `components` option (`swift-injection compile --components BankCard,PrimaryButton`): the app's own views compile to `custom` components; labeled arguments become props and closures become events.
- Expression operators (schema 1.1): `currency` and `fixed` for number formatting. The compiler maps `x.formatted(.currency(code:))`, `.formatted(.number.precision(.fractionLength(n)))`, `String(format: "%.2f", x)` and `Text(x, format: …)` to them.
- `RemoteInjectedScreen(hostState:)`: inject app state (a cart, a product list) into a remote screen and keep it updated as the app's state changes. `RuntimeValue(encoding:)` and `RuntimeValue.decode(_:)` bridge `Codable` models.
- Compiler: `LazyVGrid`, `LazyHGrid`, `Grid` and `GridRow` with literal `GridItem` columns/rows; `Color(hex:)` from `SwiftInjectionAuthoring` for colors that come from state.
- Showcase apps: Event RSVP, Onboarding, Banking (MVVM + Coordinators + DI) and Retail (TCA, with seven remote screens driven by reducer state), plus `Examples/scripts/publish-local.sh`, a local pipeline that compiles, validates, signs and serves the examples' screens.

## [0.1.0] - 2026-10-20

First release. Payload schema `1.0`.

### Runtime (`SwiftInjection`)
- Native SwiftUI rendering of about 40 components and 64 modifiers, from a JSON payload.
- `StateStore` with dotted state paths, transactional action lists (`set`, `if`, `delay`, `call`), bindings, and locals for `forEach`/`list`/`table` items.
- Expression language: arithmetic, comparison, logic, conditionals, formatting, collections, and host-function calls. Expressions never crash; errors go to `StateStore.onError`.
- Custom components: register your own SwiftUI views by name.
- JavaScript (JavaScriptCore) payload scripts, callable from actions and expressions.
- `PayloadLoader`: remote → cache → bundled fallback, with signature verification, HTTPS-only and signed-only defaults, and payload size and depth limits. `RemoteInjectedScreen` with `.nextLaunch` and `.immediately` update policies.

### Core (`SwiftInjectionCore`)
- A platform-neutral payload model, `PayloadValidator`, Ed25519 signing (`PayloadSigner`, `PayloadVerifier`), and `SchemaVersion` with forward-compatible decoding (unknown components and modifiers are skipped with warnings).

### Compiler and CLI
- `swift-injection compile`: a supported subset of SwiftUI to payloads, including `@State`, model structs, `ForEach`/`List` with bindings, inputs, navigation, sheets and alerts, helper views (shared or inlined), scripts via `SwiftInjectionAuthoring`, and `--watch`.
- `swift-injection keygen`, `sign` and `validate`.

[0.1.0]: https://github.com/blake-osondu/SwiftInjection/releases/tag/0.1.0
