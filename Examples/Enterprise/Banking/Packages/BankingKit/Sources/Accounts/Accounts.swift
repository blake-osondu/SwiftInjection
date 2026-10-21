import SwiftUI
import AppCore
import Networking
import DesignSystem
import RemoteScreens

@MainActor
public final class AccountsViewModel: ObservableObject {
    @Published public private(set) var accounts: [Account] = []
    @Published public private(set) var errorMessage: String?
    private let api: BankAPI

    public init(api: BankAPI) { self.api = api }

    public func load() async {
        do {
            accounts = try await api.accounts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Native account list, with a remote alerts banner (a payload fragment) at the top.
public struct AccountsView: View {
    @StateObject private var model: AccountsViewModel
    @ObservedObject private var coordinator: AppCoordinator
    private let remote: RemoteScreenEnvironment

    public init(api: BankAPI, coordinator: AppCoordinator, remote: RemoteScreenEnvironment) {
        _model = StateObject(wrappedValue: AccountsViewModel(api: api))
        self.coordinator = coordinator
        self.remote = remote
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RemoteScreen("AlertsBanner", environment: remote)
                ForEach(model.accounts) { account in
                    Button { coordinator.show(.accountDetail(id: account.id), in: .accounts) } label: {
                        BankCard(name: account.name, last4: account.last4, balance: account.balance)
                    }
                    .buttonStyle(.plain)
                }
                PrimaryButton(title: "Transfer money") { coordinator.show(.transfer(fromAccountID: nil), in: .accounts) }
            }
            .padding()
        }
        .navigationTitle("Accounts")
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}

@MainActor
public final class AccountDetailViewModel: ObservableObject {
    @Published public private(set) var account: Account?
    @Published public private(set) var transactions: [AccountTransaction] = []
    let accountID: String
    private let api: BankAPI

    public init(accountID: String, api: BankAPI) {
        self.accountID = accountID
        self.api = api
    }

    public func load() async {
        account = try? await api.accounts().first { $0.id == accountID }
        transactions = (try? await api.transactions(accountID: accountID)) ?? []
    }
}

public struct AccountDetailView: View {
    @StateObject private var model: AccountDetailViewModel
    @ObservedObject private var coordinator: AppCoordinator

    public init(accountID: String, api: BankAPI, coordinator: AppCoordinator) {
        _model = StateObject(wrappedValue: AccountDetailViewModel(accountID: accountID, api: api))
        self.coordinator = coordinator
    }

    public var body: some View {
        List {
            if let account = model.account {
                Section {
                    BankCard(name: account.name, last4: account.last4, balance: account.balance)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    Button("Transfer from this account") { coordinator.show(.transfer(fromAccountID: account.id), in: .accounts) }
                }
            }
            Section("Recent activity") {
                ForEach(model.transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(transaction.title)
                            Text(transaction.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        AmountText(amount: transaction.amount)
                    }
                }
            }
        }
        .navigationTitle(model.account?.name ?? "Account")
        .task { await model.load() }
    }
}

@MainActor
public final class TransferViewModel: ObservableObject {
    public enum Status: Equatable { case editing, sending, sent, failed(String) }

    @Published public private(set) var accounts: [Account] = []
    @Published public var fromID: String?
    @Published public var toID: String?
    @Published public var amountText = ""
    @Published public private(set) var status: Status = .editing
    private let api: BankAPI

    public init(fromAccountID: String?, api: BankAPI) {
        self.fromID = fromAccountID
        self.api = api
    }

    public func load() async {
        accounts = (try? await api.accounts()) ?? []
        if fromID == nil { fromID = accounts.first?.id }
        if toID == nil { toID = accounts.first { $0.id != fromID }?.id }
    }

    public var amount: Decimal? { Decimal(string: amountText) }

    /// Why the transfer can't be sent yet, or nil when it can.
    public var validationMessage: String? {
        guard let fromID, let toID else { return "Choose both accounts." }
        if fromID == toID { return BankAPIError.sameAccount.errorDescription }
        guard let amount, amount > 0 else { return BankAPIError.invalidAmount.errorDescription }
        if let balance = accounts.first(where: { $0.id == fromID })?.balance, amount > balance {
            return BankAPIError.insufficientFunds.errorDescription
        }
        return nil
    }

    public func send() async {
        guard validationMessage == nil, let fromID, let toID, let amount else { return }
        status = .sending
        do {
            try await api.transfer(from: fromID, to: toID, amount: amount)
            status = .sent
            accounts = (try? await api.accounts()) ?? accounts
        } catch {
            status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

/// Native, because moving money must never depend on downloaded UI.
public struct TransferView: View {
    @StateObject private var model: TransferViewModel

    public init(fromAccountID: String?, api: BankAPI) {
        _model = StateObject(wrappedValue: TransferViewModel(fromAccountID: fromAccountID, api: api))
    }

    public var body: some View {
        Form {
            Section {
                Picker("From", selection: $model.fromID) {
                    ForEach(model.accounts) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("To", selection: $model.toID) {
                    ForEach(model.accounts) { Text($0.name).tag(Optional($0.id)) }
                }
                TextField("Amount", text: $model.amountText).keyboardType(.decimalPad)
            }
            Section {
                switch model.status {
                case .sent:
                    Label("Transfer sent", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed(let message):
                    Text(message).foregroundStyle(.red)
                case .editing, .sending:
                    if let message = model.validationMessage, !model.amountText.isEmpty {
                        Text(message).foregroundStyle(.secondary)
                    }
                    PrimaryButton(title: model.status == .sending ? "Sending…" : "Send") { Task { await model.send() } }
                        .disabled(model.validationMessage != nil || model.status == .sending)
                }
            }
        }
        .navigationTitle("Transfer")
        .task { await model.load() }
    }
}

/// A native placeholder for the support chat, reached from the remote Help screen.
public struct ChatSupportView: View {
    public init() {}
    public var body: some View {
        ContentUnavailableViewCompat(title: "Chat with us", systemImage: "bubble.left.and.bubble.right",
                                     message: "A support agent will join shortly.")
            .navigationTitle("Support")
    }
}

/// `ContentUnavailableView` needs iOS 17; this keeps the package on iOS 16.
struct ContentUnavailableViewCompat: View {
    let title: String
    let systemImage: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 44)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(message).foregroundStyle(.secondary)
        }
        .padding()
    }
}
