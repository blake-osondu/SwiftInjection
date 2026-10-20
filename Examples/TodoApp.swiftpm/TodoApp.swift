import SwiftUI
import SwiftInjection

@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Loads the to-do screen from the local development server started by `Examples/serve.sh`, falling back to the
/// copy bundled with the app. Edit `Examples/screens/TodoScreen.swift`, save, then tap Reload.
struct ContentView: View {
    @State private var generation = 0

    var body: some View {
        VStack(spacing: 0) {
            RemoteInjectedScreen(loader: loader, updatePolicy: .immediately) { store in
                store.onError = { print("SwiftInjection:", $0) }
            } placeholder: {
                ProgressView()
            } failure: { error in
                Text(error.description).padding()
            }
            .id(generation)  // a new screen (and a fresh fetch) on reload

            Button("Reload from server") { generation += 1 }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }

    private var loader: PayloadLoader {
        PayloadLoader(configuration: .init(
            url: URL(string: "http://localhost:8000/TodoScreen.json")!,
            bundled: Bundle.main.url(forResource: "TodoScreen", withExtension: "json"),
            // Local development only: production payloads are signed and served over HTTPS.
            allowUnsigned: true,
            allowInsecureHTTP: true))
    }
}
