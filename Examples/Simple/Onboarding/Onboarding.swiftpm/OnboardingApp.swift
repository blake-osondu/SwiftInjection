import SwiftUI
import SwiftInjection

/// Onboarding is a remote, A/B-tested payload; everything after it is native. The payload hands control back
/// through the `finishOnboarding` host function, and the app (not the payload) remembers that it's been seen.
@main
struct OnboardingApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("onboardingVariant") private var variant = ""

    init() {
        // Each install is assigned a variant once, at random, and keeps it.
        if UserDefaults.standard.string(forKey: "onboardingVariant") == nil {
            UserDefaults.standard.set(Bool.random() ? "A" : "B", forKey: "onboardingVariant")
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                HomeView(variant: variant) { hasSeenOnboarding = false }
            } else {
                RemoteInjectedScreen(loader: .onboarding(variant: variant)) { store in
                    store.functions["finishOnboarding"] = { args, _ in
                        Analytics.track("onboarding_finished", ["variant": variant, "how": args.first?.displayString ?? ""])
                        hasSeenOnboarding = true
                        return .null
                    }
                    store.functions["track"] = { args, _ in
                        Analytics.track(args.first?.displayString ?? "event", ["variant": variant])
                        return .null
                    }
                }
            }
        }
    }
}

/// The native app the user lands in after onboarding.
struct HomeView: View {
    let variant: String
    let replayOnboarding: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("You're all set").font(.title.bold())
                Text("This screen is native. The onboarding before it was downloaded (variant \(variant)).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Replay onboarding", action: replayOnboarding)
            }
            .padding()
            .navigationTitle("Lumen")
        }
    }
}

/// Stands in for the app's analytics SDK.
enum Analytics {
    static func track(_ event: String, _ properties: [String: String] = [:]) {
        print("[analytics]", event, properties)
    }
}

extension PayloadLoader {
    /// The variant's signed payload from `Examples/scripts/publish-local.sh --serve`, else the bundled copy.
    static func onboarding(variant: String) -> PayloadLoader {
        let screen = variant == "B" ? "OnboardingScreenB" : "OnboardingScreen"
        return PayloadLoader(configuration: .init(
            url: URL(string: "http://localhost:8000/Onboarding/\(screen).json")!,
            bundled: Bundle.main.url(forResource: screen, withExtension: "json"),
            verifier: .developmentKey,
            allowInsecureHTTP: true))  // localhost during development; production payloads are served over HTTPS
    }
}

extension PayloadVerifier {
    /// The public key publish-local.sh copies into the app; without it, only the bundled payload is used.
    static var developmentKey: PayloadVerifier? {
        guard let url = Bundle.main.url(forResource: "payload-signing", withExtension: "pub"),
              let key = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? PayloadVerifier(base64PublicKeys: [key.trimmingCharacters(in: .whitespacesAndNewlines)])
    }
}
