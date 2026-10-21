import SwiftUI
import ComposableArchitecture
import Models
import Clients

/// The app: a native tab bar and navigation stacks. Every screen state lives here or in a child feature, and every
/// navigation decision is made here, so remote screens can only ask (via delegate actions), never navigate.
@Reducer
public struct AppFeature {
    public enum Tab: String, Equatable, Sendable {
        case shop, cart, account
    }

    @Reducer
    public enum ShopPath {
        case catalog(CatalogFeature)
        case product(ProductFeature)
    }

    @Reducer
    public enum CartPath {
        case checkout(CheckoutFeature)
        case confirmation(ConfirmationFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var tab = Tab.shop
        public var home = HomeFeature.State()
        public var shopPath = StackState<ShopPath.State>()
        public var cart = CartFeature.State()
        public var cartPath = StackState<CartPath.State>()
        public var orders: [Order] = []
        public var profile = CustomerProfile.demo

        public init(tab: Tab = .shop, cart: CartFeature.State = .init()) {
            self.tab = tab
            self.cart = cart
        }
    }

    public enum Action {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case shopPath(StackActionOf<ShopPath>)
        case cart(CartFeature.Action)
        case cartPath(StackActionOf<CartPath>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Scope(state: \.cart, action: \.cart) { CartFeature() }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.tab = tab
                return .none

            case .home(.delegate(.openProduct(let product))),
                 .shopPath(.element(_, .catalog(.delegate(.openProduct(let product))))):
                state.shopPath.append(.product(ProductFeature.State(product: product)))
                return .none
            case .home(.delegate(.openCatalog(let category))):
                state.shopPath.append(.catalog(CatalogFeature.State(category: category)))
                return .none
            case .shopPath(.element(_, .product(.delegate(.addToCart(let product, let size, let quantity))))):
                state.cart.add(product, size: size, quantity: quantity)
                return .none
            case .shopPath(.element(_, .product(.delegate(.viewCart)))):
                state.tab = .cart
                return .none

            case .cart(.delegate(.checkout)):
                state.cartPath.append(.checkout(CheckoutFeature.State(
                    lines: Array(state.cart.lines), promo: state.cart.promo,
                    address: state.profile.address, cardLast4: state.profile.cardLast4)))
                return .none
            case .cart(.delegate(.continueShopping)):
                state.tab = .shop
                return .none
            case .cartPath(.element(_, .checkout(.delegate(.orderPlaced(let order))))):
                state.orders.insert(order, at: 0)
                state.cart = CartFeature.State()
                // Replace checkout, so Back can't return to a paid order.
                state.cartPath = StackState([.confirmation(ConfirmationFeature.State(order: order))])
                return .none
            case .cartPath(.element(_, .confirmation(.delegate(.continueShopping)))):
                state.cartPath.removeAll()
                state.shopPath.removeAll()
                state.tab = .shop
                return .none

            case .home, .shopPath, .cart, .cartPath:
                return .none
            }
        }
        .forEach(\.shopPath, action: \.shopPath)
        .forEach(\.cartPath, action: \.cartPath)
    }
}

extension AppFeature.ShopPath.State: Equatable {}
extension AppFeature.CartPath.State: Equatable {}

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.tab.sending(\.tabSelected)) {
            NavigationStack(path: $store.scope(state: \.shopPath, action: \.shopPath)) {
                HomeView(store: store.scope(state: \.home, action: \.home))
            } destination: { store in
                switch store.case {
                case .catalog(let store): CatalogView(store: store)
                case .product(let store): ProductView(store: store)
                }
            }
            .tabItem { Label("Shop", systemImage: "storefront") }
            .tag(AppFeature.Tab.shop)

            NavigationStack(path: $store.scope(state: \.cartPath, action: \.cartPath)) {
                CartView(store: store.scope(state: \.cart, action: \.cart))
            } destination: { store in
                switch store.case {
                case .checkout(let store): CheckoutView(store: store)
                case .confirmation(let store): ConfirmationView(store: store)
                }
            }
            .tabItem { Label("Cart", systemImage: "cart") }
            .badge(store.cart.totals.itemCount)
            .tag(AppFeature.Tab.cart)

            NavigationStack {
                AccountView(profile: store.profile, orders: store.orders)
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
            .tag(AppFeature.Tab.account)
        }
    }
}

/// Native: the account tab, with a list of which screens in this app are remote.
struct AccountView: View {
    let profile: CustomerProfile
    let orders: [Order]

    static let remoteScreens = ["Home", "Catalog", "ProductDetail", "Cart", "CheckoutReview", "OrderConfirmation"]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text(profile.name).font(.headline)
                    Text(profile.email).font(.subheadline).foregroundStyle(.secondary)
                }
                LabeledContent("Ships to", value: profile.address.street)
                LabeledContent("Card", value: "Visa •••• \(profile.cardLast4)")
            }
            Section("Orders") {
                if orders.isEmpty {
                    Text("No orders yet").foregroundStyle(.secondary)
                }
                ForEach(orders) { order in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Order \(order.id)").font(.body.weight(.medium))
                            Text("\(order.totals.itemCount) items · arrives \(order.estimatedDelivery)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(order.totals.total, format: .currency(code: "USD")).monospacedDigit()
                    }
                }
            }
            Section {
                ForEach(Self.remoteScreens, id: \.self) { Label($0, systemImage: "antenna.radiowaves.left.and.right") }
            } header: {
                Text("Remote screens")
            } footer: {
                Text("These screens are signed SwiftInjection payloads, rendered natively. The tab bar, navigation, this account tab, payment and all business logic are native TCA.")
            }
        }
        .navigationTitle("Account")
    }
}
