import SwiftUI
import ComposableArchitecture
import Models
import Clients
import RemoteScreens

/// The cart. Lines, promo codes and totals are computed here; the remote `Cart` screen only displays them.
@Reducer
public struct CartFeature {
    @ObservableState
    public struct State: Equatable {
        public var lines: IdentifiedArrayOf<CartLine> = []
        public var promo: Promo?
        public var promoStatus = PromoStatus.none

        public enum PromoStatus: String, Equatable {
            case none, checking, invalid
        }

        /// Estimated with standard shipping; checkout recomputes with the chosen option.
        public var totals: OrderTotals { OrderTotals(lines: Array(lines), promo: promo, shipping: ShippingOption.all[0]) }

        /// How much more (after discounts) qualifies for free shipping; 0 once it does.
        public var amountToFreeShipping: Decimal {
            max(0, OrderTotals.freeShippingThreshold - (totals.subtotal - totals.discount))
        }

        public init(lines: IdentifiedArrayOf<CartLine> = [], promo: Promo? = nil) {
            self.lines = lines
            self.promo = promo
        }

        public mutating func add(_ product: Product, size: String, quantity: Int) {
            let line = CartLine(product: product, size: size, quantity: quantity)
            if let existing = lines[id: line.id] {
                lines[id: line.id]?.quantity = min(existing.quantity + quantity, ProductFeature.State.maxQuantity)
            } else {
                lines.append(line)
            }
        }
    }

    public enum Action {
        case quantityChanged(lineID: String, by: Int)
        case removeTapped(lineID: String)
        case applyPromoTapped(String)
        case promoValidated(Result<Promo?, any Error>)
        case removePromoTapped
        case checkoutTapped
        case browseTapped
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case checkout
            case continueShopping
        }
    }

    @Dependency(\.orders) var orders

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .quantityChanged(let id, let delta):
                guard let line = state.lines[id: id] else { return .none }
                let quantity = line.quantity + delta
                if quantity <= 0 {
                    state.lines.remove(id: id)
                } else {
                    state.lines[id: id]?.quantity = min(quantity, ProductFeature.State.maxQuantity)
                }
                return .none
            case .removeTapped(let id):
                state.lines.remove(id: id)
                return .none
            case .applyPromoTapped(let code):
                guard !code.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                state.promoStatus = .checking
                return .run { send in
                    await send(.promoValidated(Result { try await orders.validatePromo(code) }))
                }
            case .promoValidated(.success(let promo?)):
                state.promo = promo
                state.promoStatus = .none
                return .none
            case .promoValidated:
                state.promoStatus = .invalid
                return .none
            case .removePromoTapped:
                state.promo = nil
                return .none
            case .checkoutTapped:
                return state.lines.isEmpty ? .none : .send(.delegate(.checkout))
            case .browseTapped:
                return .send(.delegate(.continueShopping))
            case .delegate:
                return .none
            }
        }
    }
}

public struct CartView: View {
    let store: StoreOf<CartFeature>

    public init(store: StoreOf<CartFeature>) {
        self.store = store
    }

    public var body: some View {
        RemoteScreen("Cart", state: [
            "lines": Array(store.lines),
            "totals": store.totals,
            "promoCode": store.promo?.code ?? "",
            "promoStatus": store.promoStatus.rawValue,
            "amountToFreeShipping": store.amountToFreeShipping,
        ], intents: [
            "changeQuantity": { store.send(.quantityChanged(lineID: $0.string(0), by: $0.int(1) ?? 0)) },
            "remove": { store.send(.removeTapped(lineID: $0.string(0))) },
            "applyPromo": { store.send(.applyPromoTapped($0.string(0))) },
            "removePromo": { _ in store.send(.removePromoTapped) },
            "checkout": { _ in store.send(.checkoutTapped) },
            "browse": { _ in store.send(.browseTapped) },
        ])
    }
}
