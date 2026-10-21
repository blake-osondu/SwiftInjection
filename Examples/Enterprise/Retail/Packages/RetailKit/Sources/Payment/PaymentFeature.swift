import SwiftUI
import ComposableArchitecture
import Models
import Clients

/// Payment authorization. It stays native: it handles card data and talks to the payment provider, which is the
/// line remote screens shouldn't cross.
@Reducer
public struct PaymentFeature {
    @ObservableState
    public struct State: Equatable {
        public var amount: Decimal
        public var cardLast4: String
        public var status: Status = .ready

        public enum Status: Equatable {
            case ready, authorizing, declined(String)
        }

        public init(amount: Decimal, cardLast4: String) {
            self.amount = amount
            self.cardLast4 = cardLast4
        }
    }

    public enum Action: Equatable {
        case confirmTapped
        case cancelTapped
        case authorizationFinished(Result<PaymentReceipt, PaymentError>)
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case authorized(PaymentReceipt)
        }
    }

    @Dependency(\.payments) var payments
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .confirmTapped:
                guard state.status != .authorizing else { return .none }
                state.status = .authorizing
                return .run { [amount = state.amount] send in
                    do {
                        await send(.authorizationFinished(.success(try await payments.authorize(amount))))
                    } catch {
                        await send(.authorizationFinished(.failure(error as? PaymentError ?? PaymentError(error.localizedDescription))))
                    }
                }
            case .authorizationFinished(.success(let receipt)):
                return .run { send in
                    await send(.delegate(.authorized(receipt)))
                    await dismiss()
                }
            case .authorizationFinished(.failure(let error)):
                state.status = .declined(error.message)
                return .none
            case .cancelTapped:
                return .run { _ in await dismiss() }
            case .delegate:
                return .none
            }
        }
    }
}

public struct PaymentView: View {
    let store: StoreOf<PaymentFeature>

    public init(store: StoreOf<PaymentFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Northwind Pay", systemImage: "lock.shield.fill").font(.headline)
                Spacer()
                Button("Cancel") { store.send(.cancelTapped) }
                    .disabled(store.status == .authorizing)
            }
            HStack {
                Image(systemName: "creditcard.fill").font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("Visa •••• \(store.cardLast4)").font(.body.weight(.medium))
                    Text("Saved card").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Text("Total")
                Spacer()
                Text(store.amount, format: .currency(code: "USD")).font(.title2.weight(.semibold).monospacedDigit())
            }

            if case .declined(let message) = store.status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                store.send(.confirmTapped)
            } label: {
                Group {
                    if store.status == .authorizing {
                        ProgressView().tint(.white)
                    } else {
                        Label("Pay with Face ID", systemImage: "faceid")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.status == .authorizing)
        }
        .padding(24)
        .presentationDetents([.height(340)])
        .interactiveDismissDisabled(store.status == .authorizing)
    }
}
