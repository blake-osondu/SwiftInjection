import SwiftUI
import SwiftInjectionAuthoring

// The account tab. The profile and order history come from the app's AppFeature; this screen only lays them out.
// Payment details stay native: the screen gets the card's last four digits and nothing else.

struct Address {
    var street: String
    var city: String
}

struct Profile {
    var name: String
    var email: String
    var address: Address
    var cardLast4: String
}

struct Totals {
    var itemCount: Int
    var total: Double
}

struct Order: Identifiable {
    var id: String
    var totals: Totals
    var estimatedDelivery: String
}

struct Account: View {
    @State private var profile = Profile(name: "Sam Rivera", email: "sam@example.com",
                                         address: Address(street: "200 Market St", city: "San Francisco, CA 94105"),
                                         cardLast4: "4242")
    @State private var orders = [Order(id: "NW-48213", totals: Totals(itemCount: 2, total: 181.48), estimatedDelivery: "Monday, October 26")]
    @State private var remoteScreens = ["Home", "Catalog", "Account"]

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(red: 0.16, green: 0.18, blue: 0.29))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.headline)
                        Text(profile.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Shipping and payment") {
                Label(profile.address.street + ", " + profile.address.city, systemImage: "house.fill")
                Label("Visa •••• " + profile.cardLast4, systemImage: "creditcard.fill")
            }

            Section("Orders") {
                if orders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No orders yet")
                            .foregroundColor(.gray)
                        Button("Start shopping") { hostAction("startShopping") }
                            .buttonStyle(.borderless)
                    }
                } else {
                    ForEach(orders) { order in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Order " + order.id)
                                    .bold()
                                Text("\(order.totals.itemCount) items · arrives " + order.estimatedDelivery)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(order.totals.total.formatted(.currency(code: "USD")))
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section {
                ForEach(remoteScreens, id: \.self) { name in
                    Label(name, systemImage: "antenna.radiowaves.left.and.right")
                }
            } header: {
                Text("Remote screens")
            } footer: {
                Text("These screens, including this one, are signed SwiftInjection payloads rendered natively. The tab bar, navigation, payment and all business logic are native TCA.")
            }
        }
        .navigationTitle("Account")
    }
}
