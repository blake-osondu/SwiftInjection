# Retail: The Composable Architecture

A shopping app where **most of the UI is remote**. The home feed, catalog and search, product pages, cart, checkout review and order confirmation are signed SwiftInjection payloads. They use only built-in SDK views, with no custom components.

The line remote screens shouldn't cross stays native. That covers the app shell, navigation, payment authorization, and every business rule. In TCA terms, **reducers own all state and logic; remote screens are their views.**

| Area | | Why |
|---|---|---|
| Home feed | **Remote** | Merchandising rearranges it weekly |
| Catalog, search, filters, sort | **Remote** | Layout and filters change with the catalog |
| Product detail | **Remote** | Page layout, badges, and how sizes are presented |
| Cart | **Remote** | Promotions, messaging, free-shipping nudges |
| Checkout review | **Remote** | Layout and copy; every number comes from the app |
| Order confirmation | **Remote** | Cross-sells and surveys |
| Tab bar, navigation stacks | Native | Navigation is a reducer decision, never a payload's |
| Payment sheet | Native | Card data and payment authorization never touch a payload |
| Account tab | Native | |
| Prices, totals, tax, promo validation, size and quantity rules, placing orders | Native (reducers) | Business logic is tested, versioned code |

## How a remote screen plugs into TCA

```swift
public struct ProductView: View {
    let store: StoreOf<ProductFeature>

    public var body: some View {
        RemoteScreen("ProductDetail", state: [
            "product": store.product,          // Codable state, kept live in the screen
            "selectedSize": store.selectedSize,
            "quantity": store.quantity,
            "needsSize": store.needsSize,
        ], intents: [
            "selectSize": { store.send(.sizeTapped($0.string(0))) },
            "addToCart": { _ in store.send(.addToCartTapped) },
        ])
    }
}
```

- **State flows in.** `state` is written into the screen's state through `RemoteInjectedScreen(hostState:)` and updated whenever the store changes. The screen declares matching `@State` properties with placeholder values, so it still works in Previews.
- **Intents flow out.** The screen calls `hostAction("addToCart")`, and `RemoteScreen` sends the matching TCA action. Navigation happens through delegate actions handled by `AppFeature`, so a payload can ask but can't navigate.
- **No money math in payloads.** Totals, discounts, tax, free-shipping progress and per-order shipping prices are computed in Swift (`OrderTotals`) and only displayed remotely, formatted with `.formatted(.currency(code:))`.

## Architecture

```
Retail.swiftpm                  the app: Store(AppFeature), the remote screen configuration, demo launch arguments
Packages/RetailKit
  Models                        Product, CartLine, OrderTotals, Order, … (Codable; field names are what screens read)
  Clients                       CatalogClient, PaymentClient, OrderClient (TCA dependencies) and the demo catalog
  RemoteScreens                 the only module that imports SwiftInjection: RemoteScreen + RemoteArguments
  Payment                       PaymentFeature + PaymentView (native sheet)
  Features                      Home, Catalog, Product, Cart, Checkout, Confirmation, and AppFeature (tabs, StackState paths)
screens/                        the six remote screens, in SwiftUI
```

## Run it

1. `Examples/scripts/publish-local.sh --serve` compiles, signs and serves the screens, republishing on save.
2. Open `Retail.swiftpm` in Xcode and run it on an iOS 17+ simulator.

Launch arguments jump straight to a screen for demos and screenshots:
- `-demoProduct puffer`
- `-demoCatalog shoes`
- `-demoTab cart -demoCart puffer:M,mug,tote`
- `-demoTab cart -demoCart puffer:M,mug -demoCheckout YES`

## Things to try

- **Rearrange the storefront:** in `screens/Home.swift`, move the Trending grid above the categories, or change the grid to three columns. Save, then bring the app back to the foreground.
- **Try promo codes** `FALL20` and `WELCOME10` in the cart. The reducer validates them, and the remote screen only shows the result.
- **Trigger a declined payment:** order more than $1,000 of products. The native payment sheet shows the bank's decline and nothing is ordered.
- **Tamper with a served payload** in `Examples/.payloads/Retail/` without re-signing. The app refuses it and keeps the last good copy.

## Tests

`Packages/RetailKit` has `TestStore` tests for the money math, product rules, cart and promos, debounced search, checkout and payment (including declines), and a full flow from product page to confirmation:

```sh
cd Examples/Enterprise/Retail/Packages/RetailKit
xcodebuild test -scheme RetailKit-Package -destination 'platform=iOS Simulator,name=iPhone 16' -skipMacroValidation
```

`ShowcaseAppTests` in the main test suite compiles the six screens and drives them with app state, checking that each tap sends the right intent. CI runs both.
