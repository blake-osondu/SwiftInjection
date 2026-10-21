import SwiftUI
import SwiftInjectionAuthoring

// Search and browse. The search field's text is the only state this screen owns; each change goes to the app's
// CatalogFeature (`hostAction("search", query)`), which debounces, searches, and writes `results` back.

struct Category: Identifiable {
    var id: String
    var name: String
    var symbol: String
}

struct Product: Identifiable {
    var id: String
    var name: String
    var brand: String
    var price: Double
    var compareAtPrice = 0.0
    var onSale = false
    var rating: Double
    var reviewCount: Int
    var symbol: String
    var color: String
}

struct Catalog: View {
    @State private var query = ""
    @State private var category = ""          // the selected category id, or "" for all
    @State private var sort = "featured"
    @State private var isSearching = false
    @State private var categories = [Category(id: "outerwear", name: "Outerwear", symbol: "cloud.snow"),
                                     Category(id: "shoes", name: "Shoes", symbol: "shoe")]
    @State private var results = [
        Product(id: "puffer", name: "Alpine Puffer Jacket", brand: "Northwind", price: 149, compareAtPrice: 199, onSale: true,
                rating: 4.7, reviewCount: 812, symbol: "snowflake", color: "#3B6EA5"),
        Product(id: "chelsea", name: "Weatherproof Chelsea Boot", brand: "Fieldhouse", price: 129, rating: 4.6,
                reviewCount: 1204, symbol: "shoe.fill", color: "#7A4E2D"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search products", text: $query)
                        .onSubmit { hostAction("search", query) }
                }
                .padding(12)
                .background(Color(red: 0.94, green: 0.94, blue: 0.96))
                .cornerRadius(12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories) { item in
                            Button { hostAction("selectCategory", item.id) } label: {
                                Label(item.name, systemImage: item.symbol)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundColor(category == item.id ? .white : .black)
                                    .background(category == item.id ? Color(red: 0.16, green: 0.18, blue: 0.29) : Color(red: 0.94, green: 0.94, blue: 0.96))
                                    .cornerRadius(18)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 16) {
                    SortButton(title: "Featured", value: "featured", selected: sort)
                    SortButton(title: "Price ↑", value: "priceLow", selected: sort)
                    SortButton(title: "Price ↓", value: "priceHigh", selected: sort)
                    SortButton(title: "Top rated", value: "rating", selected: sort)
                }

                if isSearching && results.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No matches")
                            .font(.headline)
                        Text("Try another search or category.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    Text("\(results.count) results")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                        ForEach(results) { product in
                            ProductTile(product: product)
                        }
                    }
                    .opacity(isSearching ? 0.5 : 1)
                }
            }
            .padding(16)
        }
        .onChange(of: query) { hostAction("search", query) }
        .navigationTitle("Browse")
    }
}

struct SortButton: View {
    let title: String
    let value: String
    let selected: String

    var body: some View {
        Button { hostAction("sort", value) } label: {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundColor(selected == value ? .orange : .gray)
        }
        .buttonStyle(.plain)
    }
}

struct ProductTile: View {
    let product: Product

    var body: some View {
        Button { hostAction("openProduct", product.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Rectangle()
                        .foregroundColor(Color(hex: product.color))
                        .opacity(0.16)
                    Image(systemName: product.symbol)
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: product.color))
                }
                .frame(height: 150)
                .cornerRadius(16)
                Text(product.brand)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(product.name)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(product.price.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                    if product.onSale {
                        Text(product.compareAtPrice.formatted(.currency(code: "USD")))
                            .font(.caption)
                            .strikethrough()
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Label(product.rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
