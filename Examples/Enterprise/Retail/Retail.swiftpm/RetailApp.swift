import SwiftUI
import ComposableArchitecture
import Models
import Clients
import RemoteScreens
import Features

@main
struct RetailApp: App {
    let store = Store(initialState: Demo.initialState) { AppFeature() }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .environment(\.remoteScreens, RemoteScreenConfiguration(
                    // Signed payloads from `Examples/scripts/publish-local.sh --serve`, falling back to the bundled copies.
                    baseURL: URL(string: "http://localhost:8000/Retail")!,
                    publicKeys: Demo.developmentPublicKeys,
                    allowInsecureHTTP: true))  // localhost during development; production payloads are served over HTTPS
        }
    }
}

/// Launch arguments for demos and screenshots, e.g. `-demoTab cart -demoCart puffer:M,mug -demoCheckout YES`,
/// `-demoProduct chelsea`, or `-demoCatalog shoes`.
/// (Launch arguments land in UserDefaults' argument domain; normal launches don't set them.)
enum Demo {
    static var initialState: AppFeature.State {
        var cart = CartFeature.State()
        for item in (UserDefaults.standard.string(forKey: "demoCart") ?? "").split(separator: ",") {
            let parts = item.split(separator: ":").map(String.init)
            if let product = Catalog.products.first(where: { $0.id == parts[0] }) {
                cart.add(product, size: parts.count > 1 ? parts[1] : "", quantity: 1)
            }
        }
        let defaults = UserDefaults.standard
        let tab = defaults.string(forKey: "demoTab").flatMap(AppFeature.Tab.init(rawValue:)) ?? .shop
        var state = AppFeature.State(tab: tab, cart: cart)
        if let category = defaults.string(forKey: "demoCatalog") {
            state.shopPath.append(.catalog(CatalogFeature.State(category: category.isEmpty ? nil : category)))
        }
        if let id = defaults.string(forKey: "demoProduct"), let product = Catalog.products.first(where: { $0.id == id }) {
            state.shopPath.append(.product(ProductFeature.State(product: product)))
        }
        if defaults.bool(forKey: "demoCheckout"), !cart.lines.isEmpty {
            state.cartPath.append(.checkout(CheckoutFeature.State(lines: Array(cart.lines), promo: cart.promo,
                                                                  address: state.profile.address, cardLast4: state.profile.cardLast4)))
        }
        return state
    }

    /// The local development key `publish-local.sh` signs with (copied into Resources, never committed).
    static var developmentPublicKeys: [String] {
        guard let url = Bundle.main.url(forResource: "payload-signing", withExtension: "pub"),
              let key = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return [key.trimmingCharacters(in: .whitespacesAndNewlines)]
    }
}
