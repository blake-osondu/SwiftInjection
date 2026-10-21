import SwiftUI
import SwiftInjectionAuthoring

// The cart. Lines, the promo code and every total come from the app's CartFeature; this screen never does money
// math. Quantity changes, promo codes and checkout go back to the feature as intents.

struct Product {
    var name: String
    var symbol: String
    var color: String
}

struct Line: Identifiable {
    var id: String
    var product: Product
    var size: String
    var quantity: Int
    var lineTotal: Double
}

struct Totals {
    var itemCount: Int
    var subtotal: Double
    var discount: Double
    var shipping: Double
    var tax: Double
    var total: Double
}

struct Cart: View {
    @State private var lines = [
        Line(id: "puffer-M", product: Product(name: "Alpine Puffer Jacket", symbol: "snowflake", color: "#3B6EA5"),
             size: "M", quantity: 1, lineTotal: 149),
        Line(id: "mug", product: Product(name: "Stoneware Mug Set", symbol: "cup.and.saucer.fill", color: "#6D8B74"),
             size: "", quantity: 2, lineTotal: 64),
    ]
    @State private var totals = Totals(itemCount: 3, subtotal: 213, discount: 0, shipping: 0, tax: 17.04, total: 230.04)
    @State private var amountToFreeShipping = 0.0
    @State private var promoCode = ""         // the applied code, set by the app
    @State private var promoStatus = "none"   // "none", "checking" or "invalid"
    @State private var promoDraft = ""

    var body: some View {
        Group {
            if lines.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "cart")
                        .font(.system(size: 56))
                        .foregroundColor(.gray)
                    Text("Your cart is empty")
                        .font(.title2)
                        .bold()
                    Text("Find something you love.")
                        .foregroundColor(.gray)
                    Button("Start shopping") { hostAction("browse") }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        if amountToFreeShipping > 0 {
                            Label("Add \(amountToFreeShipping.formatted(.currency(code: "USD"))) more for free shipping", systemImage: "shippingbox")
                                .font(.subheadline)
                        } else {
                            Label("You've unlocked free standard shipping", systemImage: "shippingbox.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }

                    Section {
                        ForEach(lines) { line in
                            HStack(spacing: 12) {
                                ZStack {
                                    Rectangle()
                                        .foregroundColor(Color(hex: line.product.color))
                                        .opacity(0.16)
                                    Image(systemName: line.product.symbol)
                                        .font(.title2)
                                        .foregroundColor(Color(hex: line.product.color))
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(line.product.name)
                                        .font(.subheadline)
                                        .bold()
                                        .lineLimit(1)
                                    if !line.size.isEmpty {
                                        Text("Size " + line.size)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Text(line.lineTotal.formatted(.currency(code: "USD")))
                                        .font(.subheadline)
                                }
                                Spacer()
                                Button { hostAction("changeQuantity", line.id, -1) } label: {
                                    Image(systemName: line.quantity == 1 ? "trash.circle" : "minus.circle")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                                Text("\(line.quantity)")
                                    .monospacedDigit()
                                Button { hostAction("changeQuantity", line.id, 1) } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                                .disabled(line.quantity >= 10)
                            }
                        }
                    }

                    Section("Promo code") {
                        if promoCode.isEmpty {
                            HStack {
                                TextField("Try FALL20", text: $promoDraft)
                                Button("Apply") { hostAction("applyPromo", promoDraft) }
                                    .buttonStyle(.borderless)
                                    .disabled(promoDraft.isEmpty || promoStatus == "checking")
                            }
                            if promoStatus == "checking" {
                                ProgressView()
                            }
                            if promoStatus == "invalid" {
                                Text("That code isn't valid.")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                        } else {
                            HStack {
                                Label(promoCode + " applied", systemImage: "tag.fill")
                                    .foregroundColor(.green)
                                Spacer()
                                Button("Remove") { hostAction("removePromo") }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }

                    Section {
                        SummaryRow(title: "Subtotal (\(totals.itemCount) items)", value: totals.subtotal.formatted(.currency(code: "USD")))
                        if totals.discount > 0 {
                            SummaryRow(title: "Discount", value: "−" + totals.discount.formatted(.currency(code: "USD")))
                        }
                        SummaryRow(title: "Shipping", value: totals.shipping == 0 ? "Free" : totals.shipping.formatted(.currency(code: "USD")))
                        SummaryRow(title: "Estimated tax", value: totals.tax.formatted(.currency(code: "USD")))
                        HStack {
                            Text("Total")
                                .bold()
                            Spacer()
                            Text(totals.total.formatted(.currency(code: "USD")))
                                .bold()
                        }
                    }

                    Section {
                        Button { hostAction("checkout") } label: {
                            Text("Checkout")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Cart")
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
