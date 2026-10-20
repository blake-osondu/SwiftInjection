# Changelog

This project follows [Semantic Versioning](https://semver.org). The payload format is versioned separately by `schemaVersion` (see `SchemaVersion`).

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
