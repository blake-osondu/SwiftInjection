# Contributing

Thanks for helping. Issues and pull requests are welcome; for anything bigger than a fix, open an issue first so we can agree on the approach.

## Setup

Xcode 26 (Swift 6.2) on macOS. Clone the repository and open the folder in Xcode, or use the command line.

## Running the tests

| What | Command |
|---|---|
| Everything, on an iOS simulator | `xcodebuild test -scheme SwiftInjection-Package -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Core (platform-neutral) on macOS | `xcodebuild test -scheme SwiftInjectionCore -destination platform=macOS` |
| CLI tools on macOS | `xcodebuild test -scheme SwiftInjectionTools -destination platform=macOS` |
| Compiler on macOS | `xcodebuild test -scheme SwiftInjectionCompiler -destination platform=macOS` |

CI runs all of these on every pull request and **fails on any compiler warning in `Sources/`**. Incremental builds don't re-report warnings for files they skip, so check with a clean build before pushing (`xcodebuild clean build …`).

## Layout

| Target | What it holds |
|---|---|
| `SwiftInjectionCore` | The payload model: views, modifiers, expressions, actions, validation, signing. Foundation and CryptoKit only. |
| `SwiftInjection` | The SwiftUI runtime: components, `StateStore`, the script runtime, the loader. |
| `SwiftInjectionCompiler` | SwiftUI subset → payload, on swift-syntax. |
| `SwiftInjectionTools`, `SwiftInjectionCLI` | The `swift-injection` command. |
| `SwiftInjectionAuthoring` | `script(…)` / `runScript(…)` for screen sources. |

## Adding a component or modifier

1. **Core:** the model (`Sources/SwiftInjectionCore/Views/…ViewStore.swift`), plus a case in `InjectedView` (its switch statements and `Codable`). For a modifier: a case in `InjectedModifier` and its name in `InjectedModifier.knownNames`.
2. **Runtime:** the SwiftUI view, plus its case in `Insertable`. For a modifier: its case in `ModifierStore`.
3. **Docs:** an entry with a JSON example in [docs/PayloadReference.md](docs/PayloadReference.md). `PayloadReferenceTests` fails until it's there, and decodes every example.
4. **Tests:** render tests in `Tests/SwiftInjectionTests`. For modifiers, also add one to the fixture in `ModifierTests`.
5. **Compiler** (optional): a mapping from the SwiftUI API in `ViewCompiler` / `ModifierCompiler`, with a test and an update to [docs/Compiler.md](docs/Compiler.md).

New components and modifiers are a **minor** schema version change. Changing or removing one is a **major** change; discuss it in an issue first.

## Style

- Match the surrounding code. Comments explain *why*, not what.
- Never crash on payload input: report through `StateStore.onError` and fall back.
- The compiler never guesses: unsupported Swift is a diagnostic with a location.

## Pull requests

- Target `develop`, and keep each PR to one change.
- Describe what changed and how you tested it, and link the issue (`Closes #N`).
- Both CI checks must pass before merging.

By contributing, you agree that your contributions are licensed under the Apache License 2.0.
