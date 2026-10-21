import SwiftUI
import SwiftInjectionAuthoring
import DesignSystem

// Offers change weekly and are owned by marketing, so the tab is remote. Design-system views (PrimaryButton)
// compile to custom components the app registers; actions go through host functions the app implements.

struct User {
    var firstName: String
}

struct Offer: Identifiable {
    var id: String
    var title: String
    var detail: String
    var badge = ""
}

struct Offers: View {
    @State private var user = User(firstName: "there")  // replaced by the app with the signed-in user
    @State private var showSpringPromo = true             // the kill switch: publish `false` to hide it everywhere
    @State private var applied: [String: Any] = [:]       // offer id → true / "applying" / "failed", set by the app
    @State private var offers = [
        Offer(id: "savings-boost", title: "4.50% APY Savings Boost", detail: "Earn more on new deposits for 6 months.", badge: "New"),
        Offer(id: "cashback-card", title: "2% Cashback Card", detail: "Unlimited 2% back on every purchase, no annual fee."),
        Offer(id: "travel-cover", title: "Travel Cover", detail: "Trip cancellation and lost-bag protection when you pay with Northwind."),
    ]

    var body: some View {
        List {
            if showSpringPromo {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Spring savings challenge", systemImage: "leaf.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("Move $50 a week into savings through May and we'll add a $25 bonus.")
                            .font(.subheadline)
                        PrimaryButton(title: "Start saving") {
                            hostAction("track", "spring_promo_tapped")
                            hostAction("navigate", "transfer")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Picked for you, \(user.firstName)") {
                ForEach(offers) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(offer.title).font(.headline)
                            if !offer.badge.isEmpty {
                                Text(offer.badge)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                        }
                        Text(offer.detail)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        if applied[offer.id] == true {
                            Label("Application received", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if applied[offer.id] == "applying" {
                            ProgressView("Applying…")
                        } else {
                            PrimaryButton(title: "Apply") { hostAction("applyForOffer", offer.id) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Offers")
        .onAppear { hostAction("track", "offers_viewed") }
    }
}
