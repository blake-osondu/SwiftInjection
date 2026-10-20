import XCTest
import SwiftInjection
@testable import AppCore
@testable import Networking
@testable import Auth
@testable import RemoteScreens
@testable import Accounts

@MainActor
final class CoordinatorTests: XCTestCase {
    func testDeepLinks() {
        let coordinator = AppCoordinator()
        XCTAssertTrue(coordinator.open("transfer"))
        XCTAssertEqual(coordinator.tab, .accounts)
        XCTAssertEqual(coordinator.accountsPath, [.transfer(fromAccountID: nil)])

        XCTAssertTrue(coordinator.open("account/chk-001"))
        XCTAssertEqual(coordinator.accountsPath, [.accountDetail(id: "chk-001")], "deep links replace the stack")

        XCTAssertTrue(coordinator.open("support/chat"))
        XCTAssertEqual(coordinator.tab, .help)
        XCTAssertEqual(coordinator.helpPath, [.chatSupport])

        XCTAssertTrue(coordinator.open("offers"))
        XCTAssertEqual(coordinator.tab, .offers)
        XCTAssertFalse(coordinator.open("rm -rf /"))
    }
}

@MainActor
final class ViewModelTests: XCTestCase {
    func testLogin() async {
        let auth = AuthService(api: MockBankAPI(latency: .zero))
        let model = LoginViewModel(auth: auth)
        XCTAssertFalse(model.canSubmit)

        model.username = "alex"
        model.password = "no"
        await model.submit()
        XCTAssertEqual(model.errorMessage, BankAPIError.invalidCredentials.errorDescription)
        XCTAssertNil(auth.session)

        model.password = "demo"
        await model.submit()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(auth.session?.firstName, "Alex")
    }

    func testTransferValidationAndSend() async {
        let api = MockBankAPI(latency: .zero)
        let model = TransferViewModel(fromAccountID: "chk-001", api: api)
        await model.load()
        XCTAssertEqual(model.toID, "sav-002")

        model.amountText = "0"
        XCTAssertEqual(model.validationMessage, BankAPIError.invalidAmount.errorDescription)
        model.amountText = "1000000"
        XCTAssertEqual(model.validationMessage, BankAPIError.insufficientFunds.errorDescription)
        model.toID = "chk-001"
        model.amountText = "10"
        XCTAssertEqual(model.validationMessage, BankAPIError.sameAccount.errorDescription)

        model.toID = "sav-002"
        model.amountText = "100.50"
        XCTAssertNil(model.validationMessage)
        await model.send()
        XCTAssertEqual(model.status, .sent)
        XCTAssertEqual(model.accounts.first { $0.id == "chk-001" }?.balance, Decimal(string: "2380.05"))
        XCTAssertEqual(model.accounts.first { $0.id == "sav-002" }?.balance, Decimal(string: "12350.50"))
    }
}

@MainActor
final class RemoteBridgeTests: XCTestCase {
    private func environment(api: MockBankAPI = MockBankAPI(latency: .zero), flags: [String: Bool] = [:])
        -> (RemoteScreenEnvironment, AppCoordinator, ConsoleAnalytics) {
        let coordinator = AppCoordinator()
        let analytics = ConsoleAnalytics()
        let environment = RemoteScreenEnvironment(
            baseURL: URL(string: "https://example.com/screens")!, verifier: nil, bundle: .main,
            coordinator: coordinator, analytics: analytics, flags: InMemoryFeatureFlags(flags), api: api,
            session: { UserSession(userID: "u-1", firstName: "Alex", token: "secret") })
        return (environment, coordinator, analytics)
    }

    func testInstallsUserStateComponentsAndFunctions() throws {
        let (environment, coordinator, analytics) = environment(flags: ["maintenance_notice": true])
        let store = StateStore()
        RemoteBridge.install(on: store, screen: "Offers", environment: environment)

        XCTAssertEqual(store.value(at: ["user"]), ["firstName": "Alex"], "only what screens need; never the token")
        XCTAssertEqual(Set(store.components.keys), ["BankCard", "PrimaryButton", "AmountText"])

        let scope = StateScope(store: store)
        try scope.performThrowing([.call(name: "navigate", args: ["transfer"]), .call(name: "track", args: ["offers_viewed"])])
        XCTAssertEqual(coordinator.accountsPath, [.transfer(fromAccountID: nil)])
        XCTAssertEqual(analytics.events.last?.name, "offers_viewed")
        XCTAssertEqual(analytics.events.last?.properties, ["screen": "Offers"])

        XCTAssertEqual(scope.evaluate(.operation(.call, ["featureEnabled", "maintenance_notice"])), true)
        XCTAssertEqual(scope.evaluate(.operation(.call, ["featureEnabled", "unknown_flag"])), false)

        try scope.performThrowing([.call(name: "navigate", args: ["nowhere"])])
        XCTAssertEqual(analytics.events.last?.name, "remote_unknown_link")
    }

    func testApplyForOfferUpdatesStateWhenTheRequestFinishes() async throws {
        let api = MockBankAPI(latency: .milliseconds(50))
        let (environment, _, analytics) = environment(api: api)
        let store = StateStore()
        RemoteBridge.install(on: store, screen: "Offers", environment: environment)

        try StateScope(store: store).performThrowing([.call(name: "applyForOffer", args: ["savings-boost"])])
        XCTAssertEqual(store.value(at: ["applied", "savings-boost"]), "applying")

        for _ in 0..<50 where store.value(at: ["applied", "savings-boost"]) == "applying" {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(store.value(at: ["applied", "savings-boost"]), true)
        XCTAssertEqual(api.appliedOffers, ["savings-boost"])
        XCTAssertEqual(analytics.events.last?.name, "offer_applied")
    }

    func testDismissWhatsNew() throws {
        let (environment, coordinator, _) = environment()
        coordinator.sheet = .whatsNew
        let store = StateStore()
        RemoteBridge.install(on: store, screen: "WhatsNew", environment: environment)
        try StateScope(store: store).performThrowing([.call(name: "dismissWhatsNew", args: [])])
        XCTAssertNil(coordinator.sheet)
    }
}
