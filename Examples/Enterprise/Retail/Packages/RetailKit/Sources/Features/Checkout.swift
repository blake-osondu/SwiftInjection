import SwiftUI
import ComposableArchitecture
import Models
import Clients
import Payment
import RemoteScreens

/// Checkout review: shipping choice and the final total. Paying presents the native `PaymentFeature`; once it
/// authorizes, this feature places the order.
@Reducer
public struct CheckoutFeature {
    @ObservableState
    public struct State: Equatable {
        public var lines: [CartLine]
        public var promo: Promo?
        public var address: Address
        public var cardLast4: String
        public var shippingID = ShippingOption.all[0].id
        public var isPlacingOrder = false
        public var errorMessage = ""
        @Presents public var payment: PaymentFeature.State?

        public var shipping: ShippingOption { ShippingOption.all.first { $0.id == shippingID } ?? ShippingOption.all[0] }
        public var totals: OrderTotals { OrderTotals(lines: lines, promo: promo, shipping: shipping) }
        /// The options with what each would actually cost for this order (standard is free over the threshold).
        public var shippingOptions: [ShippingOption] {
            ShippingOption.all.map { option in
                var option = option
                option.price = OrderTotals(lines: lines, promo: promo, shipping: option).shipping
                return option
            }
        }

        public init(lines: [CartLine], promo: Promo?, address: Address, cardLast4: String) {
            self.lines = lines
            self.promo = promo
            self.address = address
            self.cardLast4 = cardLast4
        }
    }

    public enum Action {
        case shippingTapped(String)
        case payTapped
        case payment(PresentationAction<PaymentFeature.Action>)
        case orderPlaced(Result<Order, any Error>)
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case orderPlaced(Order)
        }
    }

    @Dependency(\.orders) var orders

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .shippingTapped(let id):
                guard !state.isPlacingOrder, ShippingOption.all.contains(where: { $0.id == id }) else { return .none }
                state.shippingID = id
                return .none
            case .payTapped:
                guard !state.isPlacingOrder else { return .none }
                state.errorMessage = ""
                state.payment = PaymentFeature.State(amount: state.totals.total, cardLast4: state.cardLast4)
                return .none
            case .payment(.presented(.delegate(.authorized(let receipt)))):
                state.isPlacingOrder = true
                return .run { [lines = state.lines, shipping = state.shipping, address = state.address, totals = state.totals] send in
                    await send(.orderPlaced(Result { try await orders.place(lines, shipping, address, receipt, totals) }))
                }
            case .payment:
                return .none
            case .orderPlaced(.success(let order)):
                state.isPlacingOrder = false
                return .send(.delegate(.orderPlaced(order)))
            case .orderPlaced(.failure):
                state.isPlacingOrder = false
                state.errorMessage = "We couldn't place your order. You haven't been charged."
                return .none
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$payment, action: \.payment) { PaymentFeature() }
    }
}

public struct CheckoutView: View {
    @Bindable var store: StoreOf<CheckoutFeature>

    public init(store: StoreOf<CheckoutFeature>) {
        self.store = store
    }

    public var body: some View {
        RemoteScreen("CheckoutReview", state: [
            "lines": store.lines,
            "totals": store.totals,
            "address": store.address,
            "cardLast4": store.cardLast4,
            "shippingOptions": store.shippingOptions,
            "shippingID": store.shippingID,
            "isPlacingOrder": store.isPlacingOrder,
            "errorMessage": store.errorMessage,
        ], intents: [
            "selectShipping": { store.send(.shippingTapped($0.string(0))) },
            "pay": { _ in store.send(.payTapped) },
        ])
        .sheet(item: $store.scope(state: \.payment, action: \.payment)) { paymentStore in
            PaymentView(store: paymentStore)
        }
    }
}
