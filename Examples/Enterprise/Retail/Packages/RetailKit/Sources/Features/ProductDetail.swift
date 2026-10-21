import SwiftUI
import ComposableArchitecture
import Models
import RemoteScreens

/// A product page. Size and quantity rules live here; the remote `ProductDetail` screen shows them.
@Reducer
public struct ProductFeature {
    @ObservableState
    public struct State: Equatable {
        public var product: Product
        public var selectedSize = ""
        public var quantity = 1
        public var needsSize = false
        public var added = false

        public static let maxQuantity = 10

        public init(product: Product) {
            self.product = product
        }
    }

    public enum Action: Equatable {
        case sizeTapped(String)
        case quantityChanged(by: Int)
        case addToCartTapped
        case viewCartTapped
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case addToCart(Product, size: String, quantity: Int)
            case viewCart
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sizeTapped(let size):
                guard state.product.sizes.contains(size) else { return .none }
                state.selectedSize = size
                state.needsSize = false
                return .none
            case .quantityChanged(let delta):
                state.quantity = min(max(state.quantity + delta, 1), State.maxQuantity)
                return .none
            case .addToCartTapped:
                if !state.product.sizes.isEmpty && state.selectedSize.isEmpty {
                    state.needsSize = true
                    return .none
                }
                state.added = true
                return .send(.delegate(.addToCart(state.product, size: state.selectedSize, quantity: state.quantity)))
            case .viewCartTapped:
                return .send(.delegate(.viewCart))
            case .delegate:
                return .none
            }
        }
    }
}

public struct ProductView: View {
    let store: StoreOf<ProductFeature>

    public init(store: StoreOf<ProductFeature>) {
        self.store = store
    }

    public var body: some View {
        RemoteScreen("ProductDetail", state: [
            "product": store.product,
            "selectedSize": store.selectedSize,
            "quantity": store.quantity,
            "needsSize": store.needsSize,
            "added": store.added,
        ], intents: [
            "selectSize": { store.send(.sizeTapped($0.string(0))) },
            "changeQuantity": { store.send(.quantityChanged(by: $0.int(0) ?? 0)) },
            "addToCart": { _ in store.send(.addToCartTapped) },
            "viewCart": { _ in store.send(.viewCartTapped) },
        ])
        .navigationBarTitleDisplayMode(.inline)
    }
}
