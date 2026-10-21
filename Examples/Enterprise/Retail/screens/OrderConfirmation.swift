import SwiftUI
import SwiftInjectionAuthoring

// The order confirmation. Marketing changes it for cross-sells and surveys, so it's remote. The order comes from
// the app; "Continue shopping" asks the app to reset navigation.

struct Product {
    var name: String
}

struct Line: Identifiable {
    var id: String
    var product: Product
    var quantity: Int
}

struct Totals {
    var total: Double
}

struct Address {
    var street: String
}

struct ShippingOption {
    var name: String
}

struct Order {
    var id: String
    var lines: [Line]
    var totals: Totals
    var shipping: ShippingOption
    var address: Address
    var cardLast4: String
    var estimatedDelivery: String
}

struct OrderConfirmation: View {
    @State private var feedback = ""   // set by the app once feedback is sent
    @State private var order = Order(id: "NW-48213",
                                     lines: [Line(id: "puffer-M", product: Product(name: "Alpine Puffer Jacket"), quantity: 1)],
                                     totals: Totals(total: 160.92), shipping: ShippingOption(name: "Standard"),
                                     address: Address(street: "200 Market St"), cardLast4: "4242",
                                     estimatedDelivery: "Monday, October 26")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.green)
                    .padding(.top, 24)
                VStack(spacing: 6) {
                    Text("Thanks for your order!")
                        .font(.title)
                        .bold()
                    Text("Order " + order.id)
                        .font(.headline)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Arrives " + order.estimatedDelivery, systemImage: "shippingbox.fill")
                    Label(order.shipping.name + " delivery to " + order.address.street, systemImage: "mappin.and.ellipse")
                    Label("Paid " + order.totals.total.formatted(.currency(code: "USD")) + " · Visa •••• " + order.cardLast4,
                          systemImage: "creditcard.fill")
                }
                .font(.subheadline)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.94, green: 0.94, blue: 0.96))
                .cornerRadius(16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("In this order")
                        .font(.headline)
                    ForEach(order.lines) { line in
                        HStack {
                            Text(line.product.name)
                            Spacer()
                            Text("×\(line.quantity)")
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    if feedback.isEmpty {
                        Text("How was checkout?")
                            .font(.headline)
                        HStack(spacing: 12) {
                            Button("👍 Easy") { hostAction("sendFeedback", "easy") }
                                .buttonStyle(.bordered)
                            Button("👎 Not great") { hostAction("sendFeedback", "hard") }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        Text("Thanks for the feedback!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 8)

                Button { hostAction("continueShopping") } label: {
                    Text("Continue shopping")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .navigationTitle("Order placed")
    }
}
