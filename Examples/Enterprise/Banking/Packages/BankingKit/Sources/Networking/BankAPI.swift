import Foundation

public struct Account: Identifiable, Hashable, Codable {
    public let id: String
    public var name: String
    public var last4: String
    public var balance: Decimal

    public init(id: String, name: String, last4: String, balance: Decimal) {
        self.id = id
        self.name = name
        self.last4 = last4
        self.balance = balance
    }
}

public struct AccountTransaction: Identifiable, Hashable, Codable {
    public let id: String
    public var accountID: String
    public var title: String
    public var amount: Decimal
    public var date: Date
}

public struct UserSession: Equatable {
    public let userID: String
    public let firstName: String
    public let token: String

    public init(userID: String, firstName: String, token: String) {
        self.userID = userID
        self.firstName = firstName
        self.token = token
    }
}

public enum BankAPIError: Error, Equatable, LocalizedError {
    case invalidCredentials, insufficientFunds, sameAccount, invalidAmount, notFound

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "That username and password don't match."
        case .insufficientFunds: return "There isn't enough money in that account."
        case .sameAccount: return "Choose two different accounts."
        case .invalidAmount: return "Enter an amount greater than zero."
        case .notFound: return "That account doesn't exist."
        }
    }
}

/// The bank's backend.
public protocol BankAPI: AnyObject {
    func login(username: String, password: String) async throws -> UserSession
    func accounts() async throws -> [Account]
    func transactions(accountID: String) async throws -> [AccountTransaction]
    func transfer(from: String, to: String, amount: Decimal) async throws
    func applyForOffer(_ offerID: String) async throws
}

/// An in-memory backend with sample data and a little latency, standing in for the real API.
public final class MockBankAPI: BankAPI {
    public private(set) var storedAccounts: [Account]
    public private(set) var storedTransactions: [AccountTransaction]
    public private(set) var appliedOffers: [String] = []
    private let latency: UInt64

    public init(latency: Duration = .milliseconds(300)) {
        self.latency = UInt64(latency.components.attoseconds / 1_000_000_000) + UInt64(latency.components.seconds) * 1_000_000_000
        storedAccounts = [
            Account(id: "chk-001", name: "Everyday Checking", last4: "4821", balance: 2_480.55),
            Account(id: "sav-002", name: "High-Yield Savings", last4: "9930", balance: 12_250.00),
        ]
        let now = Date()
        storedTransactions = [
            AccountTransaction(id: "t1", accountID: "chk-001", title: "Coffee Roasters", amount: -4.75, date: now.addingTimeInterval(-3_600)),
            AccountTransaction(id: "t2", accountID: "chk-001", title: "Paycheck", amount: 2_150.00, date: now.addingTimeInterval(-86_400)),
            AccountTransaction(id: "t3", accountID: "chk-001", title: "Grocery Market", amount: -82.10, date: now.addingTimeInterval(-172_800)),
            AccountTransaction(id: "t4", accountID: "sav-002", title: "Interest", amount: 41.20, date: now.addingTimeInterval(-259_200)),
        ]
    }

    private func wait() async { try? await Task.sleep(nanoseconds: latency) }

    public func login(username: String, password: String) async throws -> UserSession {
        await wait()
        guard !username.isEmpty, password.count >= 4 else { throw BankAPIError.invalidCredentials }
        return UserSession(userID: "u-1", firstName: username.capitalized, token: UUID().uuidString)
    }

    public func accounts() async throws -> [Account] {
        await wait()
        return storedAccounts
    }

    public func transactions(accountID: String) async throws -> [AccountTransaction] {
        await wait()
        return storedTransactions.filter { $0.accountID == accountID }.sorted { $0.date > $1.date }
    }

    public func transfer(from: String, to: String, amount: Decimal) async throws {
        await wait()
        guard amount > 0 else { throw BankAPIError.invalidAmount }
        guard from != to else { throw BankAPIError.sameAccount }
        guard let source = storedAccounts.firstIndex(where: { $0.id == from }),
              let destination = storedAccounts.firstIndex(where: { $0.id == to }) else { throw BankAPIError.notFound }
        guard storedAccounts[source].balance >= amount else { throw BankAPIError.insufficientFunds }
        storedAccounts[source].balance -= amount
        storedAccounts[destination].balance += amount
        let now = Date()
        storedTransactions.append(AccountTransaction(id: UUID().uuidString, accountID: from, title: "Transfer to \(storedAccounts[destination].name)", amount: -amount, date: now))
        storedTransactions.append(AccountTransaction(id: UUID().uuidString, accountID: to, title: "Transfer from \(storedAccounts[source].name)", amount: amount, date: now))
    }

    public func applyForOffer(_ offerID: String) async throws {
        await wait()
        appliedOffers.append(offerID)
    }
}
