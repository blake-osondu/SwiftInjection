import SwiftUI
import SwiftInjection
import AppCore
import Networking
import Auth
import RemoteScreens
import Accounts

/// The composition root: builds every service once and hands each module what it needs.
@MainActor
final class AppContainer: ObservableObject {
    let api: BankAPI = MockBankAPI()
    let analytics: Analytics = ConsoleAnalytics()
    let flags: FeatureFlags = InMemoryFeatureFlags(["maintenance_notice": true])
    let coordinator = AppCoordinator()
    lazy var auth = AuthService(api: api)

    lazy var remote = RemoteScreenEnvironment(
        // Signed payloads from `Examples/scripts/publish-local.sh --serve`, falling back to the bundled copies.
        baseURL: URL(string: "http://localhost:8000/Banking")!,
        verifier: .developmentKey,
        allowInsecureHTTP: true,  // localhost during development; production payloads are served over HTTPS
        bundle: .main,
        coordinator: coordinator, analytics: analytics, flags: flags, api: api,
        session: { [weak self] in self?.auth.session })
}

@main
struct BankingApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container, auth: container.auth, coordinator: container.coordinator)
        }
    }
}

struct RootView: View {
    let container: AppContainer
    @ObservedObject var auth: AuthService
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            if auth.session == nil {
                LoginView(auth: auth)
            } else {
                MainView(container: container, coordinator: coordinator)
                    .onAppear {
                        if !Demo.skipWhatsNew { coordinator.sheet = .whatsNew }
                        if let tab = Demo.tab { coordinator.tab = tab }
                    }
            }
        }
        .task {
            if let user = Demo.user, auth.session == nil {
                try? await auth.login(username: user, password: "demo")
            }
        }
    }
}

/// Launch arguments for demos and screenshots, e.g. `-demoUser alex -demoTab offers -skipWhatsNew YES`.
/// (Launch arguments land in UserDefaults' argument domain; normal launches don't set them.)
enum Demo {
    static var user: String? { UserDefaults.standard.string(forKey: "demoUser") }
    static var skipWhatsNew: Bool { UserDefaults.standard.bool(forKey: "skipWhatsNew") }
    static var tab: AppCoordinator.Tab? {
        switch UserDefaults.standard.string(forKey: "demoTab") {
        case "offers": return .offers
        case "help": return .help
        case "accounts": return .accounts
        default: return nil
        }
    }
}

/// Accounts are native; Offers and Help are remote; What's new is a remote sheet.
struct MainView: View {
    let container: AppContainer
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.tab) {
            NavigationStack(path: $coordinator.accountsPath) {
                AccountsView(api: container.api, coordinator: coordinator, remote: container.remote)
                    .navigationDestination(for: Route.self, destination: destination)
            }
            .tabItem { Label("Accounts", systemImage: "creditcard") }
            .tag(AppCoordinator.Tab.accounts)

            NavigationStack {
                RemoteScreen("Offers", environment: container.remote)
            }
            .tabItem { Label("Offers", systemImage: "gift") }
            .tag(AppCoordinator.Tab.offers)

            NavigationStack(path: $coordinator.helpPath) {
                RemoteScreen("Help", environment: container.remote)
                    .navigationDestination(for: Route.self, destination: destination)
            }
            .tabItem { Label("Help", systemImage: "questionmark.circle") }
            .tag(AppCoordinator.Tab.help)
        }
        .sheet(item: $coordinator.sheet) { _ in
            RemoteScreen("WhatsNew", environment: container.remote)
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .accountDetail(let id): AccountDetailView(accountID: id, api: container.api, coordinator: coordinator)
        case .transfer(let from): TransferView(fromAccountID: from, api: container.api)
        case .chatSupport: ChatSupportView()
        }
    }
}

extension PayloadVerifier {
    /// The public key publish-local.sh copies into the app; without it, only the bundled payloads are used.
    static var developmentKey: PayloadVerifier? {
        guard let url = Bundle.main.url(forResource: "payload-signing", withExtension: "pub"),
              let key = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? PayloadVerifier(base64PublicKeys: [key.trimmingCharacters(in: .whitespacesAndNewlines)])
    }
}
