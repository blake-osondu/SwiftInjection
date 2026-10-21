import SwiftUI
import SwiftInjection

/// The entire event page is a signed payload (Examples/Simple/EventRSVP/screens/EventScreen.swift). The app
/// only provides the loader and the one host function the page calls.
@main
struct EventRSVPApp: App {
    var body: some Scene {
        WindowGroup {
            RemoteInjectedScreen(loader: .eventScreen) { store in
                store.functions["submitRSVP"] = { args, _ in
                    // A real app would call its API here.
                    print("RSVP submitted:", args.map(\.displayString))
                    return .null
                }
            }
        }
    }
}

extension PayloadLoader {
    /// Signed payloads from the local server started by `Examples/scripts/publish-local.sh --serve`, falling back to
    /// the last good cached copy, then the copy bundled with the app.
    static var eventScreen: PayloadLoader {
        PayloadLoader(configuration: .init(
            url: URL(string: "http://localhost:8000/EventRSVP/EventScreen.json")!,
            bundled: Bundle.main.url(forResource: "EventScreen", withExtension: "json"),
            verifier: .developmentKey,
            allowInsecureHTTP: true))  // localhost during development; production payloads are served over HTTPS
    }
}

extension PayloadVerifier {
    /// The public key publish-local.sh copies into the app. Without it, remote payloads are refused and the
    /// bundled copy is shown.
    static var developmentKey: PayloadVerifier? {
        guard let url = Bundle.main.url(forResource: "payload-signing", withExtension: "pub"),
              let key = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? PayloadVerifier(base64PublicKeys: [key.trimmingCharacters(in: .whitespacesAndNewlines)])
    }
}
