# Banking: MVVM + Coordinators + DI

A banking app built the way large teams build them. Money movement and authentication stay native; content that changes weekly (offers, help, release notes, service notices) is remote, signed, and updated without a release.

| Area | | Why |
|---|---|---|
| Sign-in | Native | Never depends on downloaded UI |
| Accounts, account detail | Native | Plus a **remote alerts banner** embedded at the top, shown while the `maintenance_notice` flag is on |
| Transfers | Native | Moving money must never depend on downloaded UI |
| Offers tab | **Remote** | Marketing changes it weekly; includes a kill switch |
| Help tab | **Remote** | Support edits articles; "Chat with us" deep-links to a native screen |
| What's new sheet | **Remote** | Product updates release notes |

## Architecture

```
Banking.swiftpm                 composition root: AppContainer (DI), RootView, MainView (tabs + destinations)
Packages/BankingKit
  AppCore                       Route, AppCoordinator (tabs, stacks, sheet, deep links), Analytics, FeatureFlags
  Networking                    models, BankAPI protocol, MockBankAPI
  DesignSystem                  BankCard, PrimaryButton, AmountText, Theme
  Auth                          AuthService, LoginViewModel, LoginView
  Accounts                      AccountsView / AccountDetailView / TransferView + view models
  RemoteScreens                 the only module that imports SwiftInjection: RemoteScreen + RemoteBridge
screens/                        the remote screens, in SwiftUI (+ `components`: design-system views they use)
```

- **One integration point.** `RemoteScreens` is the only module that knows SwiftInjection exists. Feature modules embed `RemoteScreen("Offers", environment:)` like any other view.
- **`RemoteBridge`** connects payloads to the app, and payloads see nothing else:
  - **Components:** the design system's `BankCard`, `PrimaryButton` and `AmountText`, so remote screens look native. Screens use the real types and compile with `--components` (from `screens/components`).
  - **Host functions:**
    - `navigate(link)` → `AppCoordinator.open`, e.g. `transfer`, `account/<id>`, `support/chat`;
    - `track(event)` → `Analytics`;
    - `featureEnabled(flag)` → `FeatureFlags`;
    - `applyForOffer(id)`: calls the API asynchronously and writes the result back into the screen's state;
    - `dismissWhatsNew()`.
  - **State:** the signed-in user's first name, never the session token.
- **Deep links instead of types.** Payloads navigate with strings the coordinator understands, so remote screens never depend on the app's `Route` enum, and unknown links are reported to analytics instead of crashing.

## Run it

1. `Examples/scripts/publish-local.sh --serve` compiles, signs and serves the screens, republishing on save.
2. Open `Banking.swiftpm` in Xcode, run it, and sign in with any username and a 4+ character password.

For demos and screenshots, launch arguments skip ahead: `-demoUser alex -skipWhatsNew YES -demoTab offers`.

## Things to try

- **Kill switch:** in `screens/Offers.swift`, set `showSpringPromo = false` and save. Bring the app back to the foreground and the promo is gone. Remote screens reload on foreground and apply updates immediately.
- **Change an offer:** edit the `offers` array (or add one). It appears on the next foreground.
- **Turn off the maintenance banner:** set `"maintenance_notice": false` in `AppContainer`. The flag is checked through `hostValue("featureEnabled", …)`.
- **Tamper with a served payload** in `Examples/.payloads/Banking/` without re-signing. The app refuses it and keeps the last good copy.

## Tests

`Packages/BankingKit` has unit tests for the coordinator's deep links, the login and transfer view models, and `RemoteBridge`, including the asynchronous apply flow. Run them with:

```sh
cd Examples/Enterprise/Banking/Packages/BankingKit
xcodebuild test -scheme BankingKit-Package -destination 'platform=iOS Simulator,name=iPhone 16'
```

`ShowcaseAppTests` in the main test suite compiles the real screens and drives the Offers flow. CI runs both.
