# Examples

| App | Kind | What it shows |
|---|---|---|
| [TodoApp](TodoApp.swiftpm) | Quick start | One remote screen loaded from a local server, with a Reload button. Run it with `Examples/serve.sh`. |
| [Event RSVP](Simple/EventRSVP) | Simple | A whole event page served remotely: forms with validation, pickers, an alert, a JavaScript countdown, a host function for submitting, signed payloads, and the offline fallback. |
| [Onboarding](Simple/Onboarding) | Simple | A paged onboarding flow (page dots, progress, Skip/Next) served remotely as two **A/B variants**. It hands off to a native home screen through a `finishOnboarding` host function and tracks exposure through `track`. |
| [Banking](Enterprise/Banking) | Enterprise | **MVVM + Coordinators + DI** across six modules. Native sign-in, accounts and transfers; remote offers (with a kill switch), help, release notes, and an alerts banner embedded in a native screen. Design-system components and host functions (navigation, analytics, flags, async API calls) via a single `RemoteBridge`. |
| [Retail](Enterprise/Retail) | Enterprise | **The Composable Architecture**, with most of the app remote: home feed, catalog and search, product pages, cart, checkout review and confirmation. Reducers own all state and logic, and remote screens are their views. State flows in through `hostState`, and taps flow back as TCA actions. Payment, navigation and the tab bar stay native. |

Each app is an app package (`.swiftpm`) that opens in Xcode, depends on this repository by path, and is built by CI on every pull request.

## Running the showcase apps

1. Publish and serve every app's screens. This compiles, validates and **signs** them the way a release pipeline would, then republishes on every save:
   ```sh
   Examples/scripts/publish-local.sh --serve
   ```
   The first run creates a development signing key in `Examples/scripts/.dev-signing.key`. It's git-ignored and stays on your machine. The script copies its public key into each app.
2. Open an app package (e.g. `Examples/Simple/EventRSVP/EventRSVP.swiftpm`) in Xcode and run it on an iPhone simulator.
3. Edit the app's `screens/*.swift`, save, and relaunch the app twice. The default `.nextLaunch` policy downloads the update on the first launch and shows it on the next, so nobody's screen changes mid-use.

If you skip step 1, the apps show the copy bundled with them (`<App>.swiftpm/Resources`), and remote payloads are refused because there's no public key to verify them against.

## Layout

```
Examples/Simple/<App>/  (or Examples/Enterprise/<App>/)
  screens/<Screen>.swift         the screen, in SwiftUI (+ <Screen>.scripts.js)
  screens/components             optional: the app's own views the screens use, one per line
  <App>.swiftpm/                 the app; scheme <App>
    Resources/<Screen>.json      bundled fallback, written by publish-local.sh
```

Served at `http://localhost:8000/<App>/<Screen>.json` with `<Screen>.json.sig` next to it.

## Development settings

The apps load from `http://localhost` (`allowInsecureHTTP`), which is fine on a simulator during development. In production, serve payloads over HTTPS and sign them in CI with a key that never leaves it. See [Publishing](../docs/Publishing.md).
