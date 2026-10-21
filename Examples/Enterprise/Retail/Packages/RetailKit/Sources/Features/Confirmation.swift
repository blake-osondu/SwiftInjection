import SwiftUI
import ComposableArchitecture
import Models
import RemoteScreens

/// The order confirmation, a remote `OrderConfirmation` screen (marketing tweaks it for cross-sells and surveys).
@Reducer
public struct ConfirmationFeature {
    @ObservableState
    public struct State: Equatable {
        public var order: Order
        public var feedback = ""

        public init(order: Order) {
            self.order = order
        }
    }

    public enum Action: Equatable {
        case continueShoppingTapped
        case feedbackTapped(String)
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case continueShopping
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .continueShoppingTapped: return .send(.delegate(.continueShopping))
            case .feedbackTapped(let rating):
                guard ["easy", "hard"].contains(rating) else { return .none }
                state.feedback = rating
                return .none
            case .delegate: return .none
            }
        }
    }
}

public struct ConfirmationView: View {
    let store: StoreOf<ConfirmationFeature>

    public init(store: StoreOf<ConfirmationFeature>) {
        self.store = store
    }

    public var body: some View {
        RemoteScreen("OrderConfirmation", state: ["order": store.order, "feedback": store.feedback], intents: [
            "continueShopping": { _ in store.send(.continueShoppingTapped) },
            "sendFeedback": { store.send(.feedbackTapped($0.string(0))) },
        ])
        .navigationBarBackButtonHidden()
    }
}
