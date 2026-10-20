import SwiftUI
import SwiftInjection
import AppCore
import Networking
import DesignSystem

/// Everything remote screens need from the app, injected by the composition root.
@MainActor
public struct RemoteScreenEnvironment {
    /// Where signed payloads are served (`<baseURL>/<Screen>.json` + `.sig`).
    public var baseURL: URL
    public var verifier: PayloadVerifier?
    /// Accept http:// (local development only).
    public var allowInsecureHTTP: Bool
    public var bundle: Bundle
    public var coordinator: AppCoordinator
    public var analytics: Analytics
    public var flags: FeatureFlags
    public var api: BankAPI
    public var session: () -> UserSession?

    public init(baseURL: URL, verifier: PayloadVerifier?, allowInsecureHTTP: Bool = false, bundle: Bundle,
                coordinator: AppCoordinator, analytics: Analytics, flags: FeatureFlags, api: BankAPI,
                session: @escaping () -> UserSession?) {
        self.baseURL = baseURL
        self.verifier = verifier
        self.allowInsecureHTTP = allowInsecureHTTP
        self.bundle = bundle
        self.coordinator = coordinator
        self.analytics = analytics
        self.flags = flags
        self.api = api
        self.session = session
    }

    func loader(for screen: String) -> PayloadLoader {
        PayloadLoader(configuration: .init(
            url: baseURL.appendingPathComponent("\(screen).json"),
            bundled: bundle.url(forResource: screen, withExtension: "json"),
            verifier: verifier,
            allowInsecureHTTP: allowInsecureHTTP))
    }
}

/// A screen (or a fragment of one) whose UI is a signed payload. It reloads when the app returns to the foreground,
/// so a changed payload (e.g. a promo switched off) applies quickly.
public struct RemoteScreen: View {
    let name: String
    let environment: RemoteScreenEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var generation = 0

    public init(_ name: String, environment: RemoteScreenEnvironment) {
        self.name = name
        self.environment = environment
    }

    public var body: some View {
        RemoteInjectedScreen(loader: environment.loader(for: name), updatePolicy: .immediately,
                             configureStore: { RemoteBridge.install(on: $0, screen: name, environment: environment) },
                             placeholder: { ProgressView() },
                             failure: { Text($0.description).font(.footnote).foregroundStyle(.secondary).padding() })
            .id(generation)
            .onChange(of: scenePhase) { phase in
                if phase == .active { generation += 1 }
            }
    }
}

/// Connects payloads to the app: design-system components, host functions that delegate to app services, and
/// app data injected into state. Payloads only ever see these, never the services themselves.
public enum RemoteBridge {
    @MainActor
    public static func install(on store: StateStore, screen: String, environment: RemoteScreenEnvironment) {
        // App data the screens read (never secrets such as the session token).
        if let session = environment.session() {
            store.update { $0 = $0.setting(.object(["firstName": .string(session.firstName)]), at: ["user"]) }
        }

        store.components["BankCard"] = { context in
            AnyView(BankCard(name: context.prop("name") ?? "", last4: context.prop("last4") ?? "",
                             balance: Decimal(context.prop("balance", as: Double.self) ?? 0)))
        }
        store.components["PrimaryButton"] = { context in
            AnyView(PrimaryButton(title: context.prop("title") ?? "") { context.send("action") })
        }
        store.components["AmountText"] = { context in
            AnyView(AmountText(amount: Decimal(context.prop("amount", as: Double.self) ?? 0)))
        }

        let coordinator = environment.coordinator
        let analytics = environment.analytics
        let flags = environment.flags
        let api = environment.api
        store.functions["navigate"] = { args, _ in
            if let link = args.first?.displayString, !coordinator.open(link) {
                analytics.track("remote_unknown_link", ["screen": screen, "link": link])
            }
            return .null
        }
        store.functions["track"] = { args, _ in
            analytics.track(args.first?.displayString ?? "event", ["screen": screen])
            return .null
        }
        store.functions["featureEnabled"] = { args, _ in
            .bool(flags.isEnabled(args.first?.displayString ?? ""))
        }
        store.functions["dismissWhatsNew"] = { _, _ in
            coordinator.sheet = nil
            return .null
        }
        // Asynchronous work: mark the offer as applying, call the API, then record the result in the screen's state.
        store.functions["applyForOffer"] = { [weak store] args, state in
            guard let offerID = args.first?.displayString else { return .null }
            state = state.setting(.string("applying"), at: ["applied", offerID])
            Task { @MainActor in
                let result: RuntimeValue
                do {
                    try await api.applyForOffer(offerID)
                    analytics.track("offer_applied", ["offer": offerID])
                    result = .bool(true)
                } catch {
                    result = .string("failed")
                }
                store?.update { $0 = $0.setting(result, at: ["applied", offerID]) }
            }
            return .null
        }
    }
}
