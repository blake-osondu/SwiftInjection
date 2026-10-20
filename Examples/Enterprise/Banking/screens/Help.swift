import SwiftUI
import SwiftInjectionAuthoring
import DesignSystem

// Help content changes often and is written by support, so it's remote. Articles open within the payload;
// "Chat with us" deep-links to a native screen.

struct Help: View {
    var body: some View {
        List {
            Section("Popular") {
                NavigationLink("Freeze a lost card") {
                    Article(title: "Freeze a lost card", text: "Open Accounts, choose the card and tap Freeze. Unfreeze it any time; nothing is canceled.")
                }
                NavigationLink("Transfer limits") {
                    Article(title: "Transfer limits", text: "You can move up to $10,000 a day between your own accounts. Larger transfers are reviewed within one business day.")
                }
                NavigationLink("Dispute a charge") {
                    Article(title: "Dispute a charge", text: "Tap the transaction, then Report a problem. We'll credit your account while we investigate.")
                }
            }
            Section {
                PrimaryButton(title: "Chat with us") { hostAction("navigate", "support/chat") }
            }
        }
        .navigationTitle("Help")
    }
}

struct Article: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .padding()
        }
        .navigationTitle(title)
    }
}
