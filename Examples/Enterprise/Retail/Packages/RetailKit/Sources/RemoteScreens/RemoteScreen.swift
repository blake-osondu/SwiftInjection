import SwiftUI
import SwiftInjection

/// Where remote screens come from. The app sets it once with `.environment(\.remoteScreens, …)`.
public struct RemoteScreenConfiguration: Sendable {
    /// Signed payloads are served at `<baseURL>/<Screen>.json` (+ `.sig`).
    public var baseURL: URL
    /// Public keys payloads must be signed with.
    public var publicKeys: [String]
    /// Accept http:// (local development only).
    public var allowInsecureHTTP: Bool
    /// Where the bundled fallback payloads are.
    public var bundle: Bundle

    public init(baseURL: URL, publicKeys: [String], allowInsecureHTTP: Bool = false, bundle: Bundle = .main) {
        self.baseURL = baseURL
        self.publicKeys = publicKeys
        self.allowInsecureHTTP = allowInsecureHTTP
        self.bundle = bundle
    }

    func loader(for screen: String) -> PayloadLoader {
        PayloadLoader(configuration: .init(
            url: baseURL.appendingPathComponent("\(screen).json"),
            bundled: bundle.url(forResource: screen, withExtension: "json"),
            verifier: try? PayloadVerifier(base64PublicKeys: publicKeys),
            allowInsecureHTTP: allowInsecureHTTP))
    }
}

extension EnvironmentValues {
    @Entry public var remoteScreens = RemoteScreenConfiguration(baseURL: URL(string: "https://invalid.example")!, publicKeys: [])
}

/// The arguments a remote screen passed to an intent: `hostAction("addToCart", product.id, size, quantity)`.
public struct RemoteArguments: Sendable {
    let values: [RuntimeValue]

    public init(_ values: [RuntimeValue]) { self.values = values }

    public var count: Int { values.count }

    public func string(_ index: Int) -> String {
        guard values.indices.contains(index) else { return "" }
        if case .number(let number) = values[index], number == number.rounded() { return String(Int(number)) }
        return values[index].displayString
    }

    public func int(_ index: Int) -> Int? {
        guard values.indices.contains(index) else { return nil }
        switch values[index] {
        case .number(let number): return Int(exactly: number)
        case .string(let string): return Int(string)
        default: return nil
        }
    }
}

/// A screen whose UI is a signed remote payload, driven by a feature's state.
///
/// - `state` is written into the screen's state by name and kept in sync, so the screen always shows the feature's
///   current state (`["cart": store.lines, "totals": store.totals]`).
/// - `intents` are the host functions the screen can call (`hostAction("checkout")`); each one sends a feature action.
///
/// The screen holds no business state of its own beyond view-local things like a text field draft.
public struct RemoteScreen: View {
    let name: String
    let state: [String: RuntimeValue]
    let intents: [String: @MainActor (RemoteArguments) -> Void]
    @Environment(\.remoteScreens) private var configuration
    @Environment(\.scenePhase) private var scenePhase
    @State private var generation = 0

    public init(_ name: String, state: [String: any Encodable] = [:],
                intents: [String: @MainActor (RemoteArguments) -> Void] = [:]) {
        self.name = name
        self.state = state.compactMapValues { try? RuntimeValue(encoding: $0) }
        self.intents = intents
    }

    public var body: some View {
        RemoteInjectedScreen(
            loader: configuration.loader(for: name), updatePolicy: .immediately, hostState: state,
            configureStore: { store in
                for (intent, handler) in intents {
                    store.functions[intent] = { args, _ in
                        handler(RemoteArguments(args))
                        return .null
                    }
                }
            },
            placeholder: { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) },
            failure: { error in
                ContentUnavailableView("Couldn't load this screen", systemImage: "wifi.exclamationmark",
                                       description: Text(error.description))
            })
            // Reload when the app comes back to the foreground, so a newly published screen shows up quickly.
            .id(generation)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { generation += 1 }
            }
    }
}
