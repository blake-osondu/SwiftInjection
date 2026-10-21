import SwiftUI
import SwiftInjectionAuthoring

// Checkout review. Everything shown comes from the app's CheckoutFeature, including what each delivery option
// costs for this order. "Pay" asks the feature to present the native payment sheet: card handling and payment
// authorization never happen in a payload.

struct Product {
    var name: String
}

struct Line: Identifiable {
    var id: String
    var product: Product
    var quantity: Int
    var lineTotal: Double
}

struct Totals {
    var subtotal: Double
    var discount: Double
    var shipping: Double
    var tax: Double
    var total: Double
}

struct Address {
    var name: String
    var street: String
    var city: String
}

struct ShippingOption: Identifiable {
    var id: String
    var name: String
    var detail: String
    var price: Double
}

struct CheckoutReview: View {
    @State private var lines = [Line(id: "puffer-M", product: Product(name: "Alpine Puffer Jacket"), quantity: 1, lineTotal: 149)]
    @State private var totals = Totals(subtotal: 149, discount: 0, shipping: 0, tax: 11.92, total: 160.92)
    @State private var address = Address(name: "Sam Rivera", street: "200 Market St", city: "San Francisco, CA 94105")
    @State private var cardLast4 = "4242"
    @State private var shippingOptions = [
        ShippingOption(id: "standard", name: "Standard", detail: "3–5 business days · free over $75", price: 0),
        ShippingOption(id: "express", name: "Express", detail: "1–2 business days", price: 12),
    ]
    @State private var shippingID = "standard"
    @State private var isPlacingOrder = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            Section("Ship to") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(address.name)
                        .bold()
                    Text(address.street)
                    Text(address.city)
                }
                .font(.subheadline)
            }

            Section("Delivery") {
                ForEach(shippingOptions) { option in
                    Button { hostAction("selectShipping", option.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: shippingID == option.id ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.name)
                                Text(option.detail)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(option.price == 0 ? "Free" : option.price.formatted(.currency(code: "USD")))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isPlacingOrder)
                }
            }

            Section("Items") {
                ForEach(lines) { line in
                    HStack {
                        Text("\(line.quantity)×")
                            .foregroundColor(.gray)
                        Text(line.product.name)
                            .lineLimit(1)
                        Spacer()
                        Text(line.lineTotal.formatted(.currency(code: "USD")))
                    }
                    .font(.subheadline)
                }
            }

            Section("Payment") {
                Label("Visa •••• " + cardLast4, systemImage: "creditcard.fill")
            }

            Section {
                SummaryRow(title: "Subtotal", value: totals.subtotal.formatted(.currency(code: "USD")))
                if totals.discount > 0 {
                    SummaryRow(title: "Discount", value: "−" + totals.discount.formatted(.currency(code: "USD")))
                }
                SummaryRow(title: "Shipping", value: totals.shipping == 0 ? "Free" : totals.shipping.formatted(.currency(code: "USD")))
                SummaryRow(title: "Tax", value: totals.tax.formatted(.currency(code: "USD")))
                HStack {
                    Text("Total")
                        .bold()
                    Spacer()
                    Text(totals.total.formatted(.currency(code: "USD")))
                        .bold()
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }

            Section {
                Button { hostAction("pay") } label: {
                    HStack {
                        Spacer()
                        if isPlacingOrder {
                            ProgressView("Placing your order…")
                        } else {
                            Label("Pay " + totals.total.formatted(.currency(code: "USD")), systemImage: "lock.fill")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPlacingOrder)
            }
        }
        .navigationTitle("Review order")
    }
}

struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
        }
    }
}
