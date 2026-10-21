import SwiftUI
import SwiftInjectionAuthoring

// The storefront. Merchandising rearranges it weekly, so it's remote. The app's HomeFeature (TCA) loads the feed
// and writes it into `feed`; taps go back to the feature as intents (`hostAction("openProduct", id)`), and the
// feature decides where to navigate. The values below are placeholders for Previews.

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

struct Feed {
    var headline: String
    var subheadline: String
    var categories: [Category]
    var featured: [Product]
    var trending: [Product]
}

struct Home: View {
    @State private var isLoading = false
    @State private var feed = Feed(
        headline: "The Fall Edit",
        subheadline: "Layers, boots and everything cozy. Up to 30% off.",
        categories: [Category(id: "outerwear", name: "Outerwear", symbol: "cloud.snow"),
                     Category(id: "shoes", name: "Shoes", symbol: "shoe")],
        featured: [Product(id: "puffer", name: "Alpine Puffer Jacket", brand: "Northwind", price: 149, compareAtPrice: 199,
                           onSale: true, rating: 4.7, reviewCount: 812, symbol: "snowflake", color: "#3B6EA5")],
        trending: [Product(id: "tote", name: "Canvas Market Tote", brand: "Common Goods", price: 38, rating: 4.8,
                           reviewCount: 2210, symbol: "bag.fill", color: "#C8A96E")])

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 120)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Button { hostAction("search") } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search jackets, boots, bags…")
                            Spacer()
                        }
                        .foregroundColor(.gray)
                        .padding(12)
                        .background(Color(red: 0.94, green: 0.94, blue: 0.96))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEW SEASON")
                            .font(.caption)
                            .bold()
                            .kerning(1.5)
                            .foregroundColor(.orange)
                        Text(feed.headline)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        Text(feed.subheadline)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Button { hostAction("openCategory", "outerwear") } label: {
                            Text("Shop outerwear")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.orange)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.16, green: 0.18, blue: 0.29))
                    .cornerRadius(20)

                    SectionTitle(title: "Shop by category")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(feed.categories) { category in
                                Button { hostAction("openCategory", category.id) } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: category.symbol)
                                            .font(.title2)
                                            .frame(width: 64, height: 64)
                                            .background(Color(red: 0.94, green: 0.94, blue: 0.96))
                                            .cornerRadius(32)
                                        Text(category.name)
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SectionTitle(title: "On sale now")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(feed.featured) { product in
                                ProductTile(product: product)
                                    .frame(width: 170)
                            }
                        }
                    }

                    SectionTitle(title: "Trending")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
                        ForEach(feed.trending) { product in
                            ProductTile(product: product)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Northwind")
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .bold()
    }
}

/// A product in a grid or carousel. Its color comes from the product data.
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
