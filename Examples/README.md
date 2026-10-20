# Example: a to-do screen updated without a release

`TodoApp.swiftpm` is an iOS app whose main screen is downloaded at runtime. `screens/TodoScreen.swift` is that screen, written in ordinary SwiftUI and compiled to a payload.

## Run it

1. Start the development server. It compiles `screens/TodoScreen.swift` on every save and serves it at `http://localhost:8000/TodoScreen.json`:
   ```sh
   Examples/serve.sh
   ```
2. Open `Examples/TodoApp.swiftpm` in Xcode and run it on an iPhone simulator.
3. Edit `screens/TodoScreen.swift`: change the title, add a to-do, restyle a row. Save it, then tap **Reload from server** in the app. The screen updates without rebuilding the app.

Stop the server and relaunch the app: it shows the last version it downloaded (from its cache). Delete the app and launch it with no server: it shows the copy bundled in `TodoApp.swiftpm/Resources`.

## What to look at

- **`TodoApp.swiftpm/TodoApp.swift`:** the whole integration, a `RemoteInjectedScreen` with a `PayloadLoader`.
- **`screens/TodoScreen.swift`:** a model struct, `@State`, `List($todos)` with a `@Binding` row view, a sheet and a navigation title. See [docs/Compiler.md](../docs/Compiler.md) for what the compiler supports.

## Going to production

The example loads unsigned payloads over HTTP from `localhost` (`allowUnsigned`, `allowInsecureHTTP`). That's for local development only. For a real app, sign payloads and serve them over HTTPS, as described in [docs/Publishing.md](../docs/Publishing.md), and pass a `PayloadVerifier` instead.
