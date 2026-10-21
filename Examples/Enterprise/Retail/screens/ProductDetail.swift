import SwiftUI
import SwiftInjectionAuthoring

// A product page. The app's ProductFeature owns the selected size, quantity and the add-to-cart rules (a size is
// required, quantity is 1–10); this screen shows that state and sends taps back as intents.

struct Product: Identifiable {
    var id: String
    var name: String
    var brand: String
    var price: Double
    var compareAtPrice = 0.0
    var onSale = false
    var rating: Double
    var reviewCount: Int
    var summary: String
    var symbol: String
    var color: String
    var sizes: [String]
}

struct ProductDetail: View {
    @State private var product = Product(id: "puffer", name: "Alpine Puffer Jacket", brand: "Northwind", price: 149,
                                         compareAtPrice: 199, onSale: true, rating: 4.7, reviewCount: 812,
                                         summary: "Recycled down fill, a water-resistant shell and a packable hood.",
                                         symbol: "snowflake", color: "#3B6EA5", sizes: ["S", "M", "L", "XL"])
    @State private var selectedSize = ""
    @State private var quantity = 1
    @State private var needsSize = false
    @State private var added = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Rectangle()
                        .foregroundColor(Color(hex: product.color))
                        .opacity(0.16)
                    Image(systemName: product.symbol)
                        .font(.system(size: 120))
                        .foregroundColor(Color(hex: product.color))
                }
                .frame(height: 300)
                .cornerRadius(24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.brand)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(product.name)
                        .font(.title)
                        .bold()
                }

                HStack(spacing: 8) {
                    Text(product.price.formatted(.currency(code: "USD")))
                        .font(.title2)
                        .bold()
                    if product.onSale {
                        Text(product.compareAtPrice.formatted(.currency(code: "USD")))
                            .strikethrough()
                            .foregroundColor(.gray)
                        Text("SALE")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text(product.rating.formatted(.number.precision(.fractionLength(1))))
                        .bold()
                    Text("(\(product.reviewCount))")
                        .foregroundColor(.gray)
                }

                Text(product.summary)
                    .foregroundColor(.gray)

                if !product.sizes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Size")
                            .font(.headline)
                        HStack(spacing: 10) {
                            ForEach(product.sizes, id: \.self) { size in
                                Button { hostAction("selectSize", size) } label: {
                                    Text(size)
                                        .font(.subheadline)
                                        .bold()
                                        .frame(width: 52, height: 40)
                                        .foregroundColor(selectedSize == size ? .white : .black)
                                        .background(selectedSize == size ? Color(red: 0.16, green: 0.18, blue: 0.29) : Color(red: 0.94, green: 0.94, blue: 0.96))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if needsSize {
                            Label("Choose a size first", systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }

                HStack(spacing: 16) {
                    Text("Quantity")
                        .font(.headline)
                    Spacer()
                    Button { hostAction("changeQuantity", -1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(quantity <= 1)
                    Text("\(quantity)")
                        .font(.title3)
                        .monospacedDigit()
                    Button { hostAction("changeQuantity", 1) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(quantity >= 10)
                }

                Button { hostAction("addToCart") } label: {
                    Label("Add to cart", systemImage: "cart.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                if added {
                    HStack {
                        Label("Added to your cart", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Button("View cart") { hostAction("viewCart") }
                    }
                    .font(.subheadline)
                }
            }
            .padding(16)
        }
        .navigationTitle(product.name)
    }
}
