import Foundation
import ComposableArchitecture
import Models

// Dependencies the features use. Live values are in-memory stand-ins for a real backend; tests override them.

public enum ProductSort: String, CaseIterable, Sendable {
    case featured, priceLow, priceHigh, rating
}

@DependencyClient
public struct CatalogClient: Sendable {
    public var home: @Sendable () async throws -> HomeFeed
    public var search: @Sendable (_ query: String, _ category: String?, _ sort: ProductSort) async throws -> [Product]
    public var product: @Sendable (_ id: String) async throws -> Product
}

@DependencyClient
public struct PaymentClient: Sendable {
    /// Authorizes a charge with the saved card. Throws `PaymentError` when it's declined.
    public var authorize: @Sendable (_ amount: Decimal) async throws -> PaymentReceipt
}

public struct PaymentError: Error, Equatable, LocalizedError {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

@DependencyClient
public struct OrderClient: Sendable {
    public var place: @Sendable (_ lines: [CartLine], _ shipping: ShippingOption, _ address: Address,
                                 _ receipt: PaymentReceipt, _ totals: OrderTotals) async throws -> Order
    public var validatePromo: @Sendable (_ code: String) async throws -> Promo?
}

public struct CustomerProfile: Equatable, Sendable {
    public var name: String
    public var email: String
    public var address: Address
    public var cardLast4: String

    public static let demo = CustomerProfile(name: "Sam Rivera", email: "sam@example.com",
                                             address: Address(name: "Sam Rivera", street: "200 Market St", city: "San Francisco, CA 94105"),
                                             cardLast4: "4242")
}

// MARK: - Live (in-memory) values

extension CatalogClient: DependencyKey {
    public static let liveValue = CatalogClient(
        home: {
            try await Task.sleep(for: .milliseconds(150))
            return HomeFeed(headline: "The Fall Edit", subheadline: "Layers, boots and everything cozy. Up to 30% off.",
                            categories: Catalog.categories,
                            featured: Catalog.products.filter { $0.compareAtPrice != nil },
                            trending: Array(Catalog.products.sorted { $0.reviewCount > $1.reviewCount }.prefix(6)))
        },
        search: { query, category, sort in
            try await Task.sleep(for: .milliseconds(100))
            return Catalog.search(query, category: category, sort: sort)
        },
        product: { id in
            guard let product = Catalog.products.first(where: { $0.id == id }) else { throw CancellationError() }
            return product
        })
}

extension PaymentClient: DependencyKey {
    public static let liveValue = PaymentClient(authorize: { amount in
        try await Task.sleep(for: .milliseconds(900))
        // The demo bank declines very large orders, so the failure path can be tried.
        if amount > 1_000 { throw PaymentError("Your bank declined this payment. Try a smaller order.") }
        return PaymentReceipt(authorizationID: "AUTH-\(Int.random(in: 100_000...999_999))", cardLast4: CustomerProfile.demo.cardLast4)
    })
}

extension OrderClient: DependencyKey {
    public static let liveValue = OrderClient(
        place: { lines, shipping, address, receipt, totals in
            try await Task.sleep(for: .milliseconds(300))
            let days = shipping.id == "express" ? 2 : 5
            let delivery = Calendar.current.date(byAdding: .day, value: days, to: Date())!
            return Order(id: "NW-\(Int.random(in: 10_000...99_999))", lines: lines, totals: totals, shipping: shipping,
                         address: address, cardLast4: receipt.cardLast4,
                         estimatedDelivery: delivery.formatted(.dateTime.weekday(.wide).month().day()))
        },
        validatePromo: { code in
            try await Task.sleep(for: .milliseconds(200))
            return Catalog.promos[code.uppercased().trimmingCharacters(in: .whitespaces)]
        })
}

extension DependencyValues {
    public var catalog: CatalogClient {
        get { self[CatalogClient.self] }
        set { self[CatalogClient.self] = newValue }
    }
    public var payments: PaymentClient {
        get { self[PaymentClient.self] }
        set { self[PaymentClient.self] = newValue }
    }
    public var orders: OrderClient {
        get { self[OrderClient.self] }
        set { self[OrderClient.self] = newValue }
    }
}

// MARK: - Demo catalog

public enum Catalog {
    public static let categories = [
        Category(id: "outerwear", name: "Outerwear", symbol: "cloud.snow"),
        Category(id: "shoes", name: "Shoes", symbol: "shoe"),
        Category(id: "bags", name: "Bags", symbol: "bag"),
        Category(id: "home", name: "Home", symbol: "sofa"),
        Category(id: "tech", name: "Tech", symbol: "headphones"),
    ]

    public static let products = [
        Product(id: "puffer", name: "Alpine Puffer Jacket", brand: "Northwind", category: "outerwear", price: 149, compareAtPrice: 199,
                rating: 4.7, reviewCount: 812, summary: "Recycled down fill, a water-resistant shell and a packable hood.",
                symbol: "snowflake", color: "#3B6EA5", sizes: ["S", "M", "L", "XL"]),
        Product(id: "rain-shell", name: "Harbor Rain Shell", brand: "Northwind", category: "outerwear", price: 98,
                rating: 4.4, reviewCount: 356, summary: "Seam-sealed, breathable and light enough to keep in any bag.",
                symbol: "cloud.rain", color: "#2E7D6B", sizes: ["S", "M", "L"]),
        Product(id: "chelsea", name: "Weatherproof Chelsea Boot", brand: "Fieldhouse", category: "shoes", price: 129, compareAtPrice: 160,
                rating: 4.6, reviewCount: 1204, summary: "Waxed leather, a cushioned footbed and a grippy sole.",
                symbol: "shoe.fill", color: "#7A4E2D", sizes: ["7", "8", "9", "10", "11"]),
        Product(id: "runner", name: "Cloudstep Runner", brand: "Fieldhouse", category: "shoes", price: 110,
                rating: 4.5, reviewCount: 640, summary: "A responsive foam midsole for long days on your feet.",
                symbol: "figure.run", color: "#D9534F", sizes: ["7", "8", "9", "10", "11"]),
        Product(id: "tote", name: "Canvas Market Tote", brand: "Common Goods", category: "bags", price: 38,
                rating: 4.8, reviewCount: 2210, summary: "Heavy canvas, leather handles and an inside zip pocket.",
                symbol: "bag.fill", color: "#C8A96E"),
        Product(id: "backpack", name: "Commuter Backpack 22L", brand: "Common Goods", category: "bags", price: 89, compareAtPrice: 110,
                rating: 4.6, reviewCount: 978, summary: "A padded laptop sleeve and a luggage pass-through.",
                symbol: "backpack.fill", color: "#4A4A4A"),
        Product(id: "throw", name: "Merino Throw Blanket", brand: "Hearth", category: "home", price: 120,
                rating: 4.9, reviewCount: 431, summary: "Soft, warm and machine-washable merino wool.",
                symbol: "square.stack.3d.down.forward.fill", color: "#B5838D"),
        Product(id: "mug", name: "Stoneware Mug Set", brand: "Hearth", category: "home", price: 32,
                rating: 4.7, reviewCount: 1530, summary: "Four hand-glazed 12oz mugs, dishwasher safe.",
                symbol: "cup.and.saucer.fill", color: "#6D8B74"),
        Product(id: "headphones", name: "Quiet Over-Ear Headphones", brand: "Arc", category: "tech", price: 199, compareAtPrice: 249,
                rating: 4.5, reviewCount: 2875, summary: "Active noise cancelling and 30-hour battery life.",
                symbol: "headphones", color: "#5B5F97"),
        Product(id: "speaker", name: "Pocket Speaker", brand: "Arc", category: "tech", price: 59,
                rating: 4.3, reviewCount: 702, summary: "Big sound, waterproof, and it clips to your bag.",
                symbol: "hifispeaker.fill", color: "#E09F3E"),
    ]

    public static let promos = ["FALL20": Promo(code: "FALL20", percentOff: 20), "WELCOME10": Promo(code: "WELCOME10", percentOff: 10)]

    public static func search(_ query: String, category: String?, sort: ProductSort) -> [Product] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        var results = products.filter { product in
            (category == nil || product.category == category)
                && (query.isEmpty || [product.name, product.brand, product.category].contains { $0.lowercased().contains(query) })
        }
        switch sort {
        case .featured: break
        case .priceLow: results.sort { $0.price < $1.price }
        case .priceHigh: results.sort { $0.price > $1.price }
        case .rating: results.sort { $0.rating > $1.rating }
        }
        return results
    }
}
