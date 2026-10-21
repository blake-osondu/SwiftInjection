import SwiftUI
import SwiftInjectionAuthoring

// Variant A of the onboarding flow, served remotely so product can change the copy, order and imagery
// (and run experiments) without a release. Finishing calls the app's `finishOnboarding` host function, which
// hands off to the native home screen.

struct OnboardingScreen: View {
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { hostAction("finishOnboarding", "skipped") }
                    .padding()
            }

            TabView(selection: $page) {
                OnboardingPage(symbol: "sparkles", title: "Welcome to Lumen",
                               message: "Your days, organized into one calm timeline.", tint: .purple)
                OnboardingPage(symbol: "bell.badge", title: "Only what matters",
                               message: "Smart reminders arrive when you can act on them, not before.", tint: .orange)
                OnboardingPage(symbol: "lock.shield", title: "Private by design",
                               message: "Everything stays on your device unless you choose to sync.", tint: .green)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: page)

            ProgressView(value: Double(page + 1), total: 3)
                .padding(.horizontal, 32)

            Button(page < 2 ? "Next" : "Get started") {
                if page < 2 {
                    page += 1
                } else {
                    hostAction("finishOnboarding", "completed")
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear { hostAction("track", "onboarding_shown") }
    }
}

struct OnboardingPage: View {
    let symbol: String
    let title: String
    let message: String
    var tint: Color = .blue

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundColor(tint)
            Text(title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            Text(message)
                .font(.callout)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
