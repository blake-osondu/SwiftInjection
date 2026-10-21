import SwiftUI

/// Native destinations. Remote screens reach them through deep links (`navigate("transfer")`), so payloads
/// never depend on the app's types.
public enum Route: Hashable {
    case accountDetail(id: String)
    case transfer(fromAccountID: String?)
    case chatSupport
}

/// Owns navigation for the whole app: the selected tab, each tab's stack, and the sheet.
@MainActor
public final class AppCoordinator: ObservableObject {
    public enum Tab: Hashable { case accounts, offers, help }
    public enum Sheet: String, Identifiable { case whatsNew; public var id: String { rawValue } }

    @Published public var tab: Tab = .accounts
    @Published public var accountsPath: [Route] = []
    @Published public var helpPath: [Route] = []
    @Published public var sheet: Sheet?

    public init() {}

    public func show(_ route: Route, in tab: Tab) {
        self.tab = tab
        switch tab {
        case .accounts: accountsPath.append(route)
        case .help: helpPath.append(route)
        case .offers: break
        }
    }

    /// Opens a deep link such as `accounts`, `account/chk-001`, `transfer`, `transfer/sav-002`, `offers`, `help`
    /// or `support/chat`. Returns false for links it doesn't recognize.
    @discardableResult
    public func open(_ link: String) -> Bool {
        let parts = link.split(separator: "/").map(String.init)
        switch (parts.first, parts.count) {
        case ("accounts", 1): tab = .accounts; accountsPath = []
        case ("account", 2): accountsPath = []; show(.accountDetail(id: parts[1]), in: .accounts)
        case ("transfer", 1): accountsPath = []; show(.transfer(fromAccountID: nil), in: .accounts)
        case ("transfer", 2): accountsPath = []; show(.transfer(fromAccountID: parts[1]), in: .accounts)
        case ("offers", 1): tab = .offers
        case ("help", 1): tab = .help; helpPath = []
        case ("support", 2) where parts[1] == "chat": show(.chatSupport, in: .help)
        default: return false
        }
        return true
    }
}
