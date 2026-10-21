import Foundation

// Plain Codable models. Features keep them in state; RemoteScreens encodes them into remote screens' state, so
// their field names are the names screens use (`product.name`, `line.quantity`).

public struct Product: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var brand: String
    public var category: String
    public var price: Decimal
    public var compareAtPrice: Decimal?
    public var rating: Double
    public var reviewCount: Int
    public var summary: String
    /// An SF Symbol standing in for product photography.
    public var symbol: String
    /// The product's tile color, `#RRGGBB`.
    public var color: String
    public var sizes: [String]

    public init(id: String, name: String, brand: String, category: String, price: Decimal, compareAtPrice: Decimal? = nil,
                rating: Double, reviewCount: Int, summary: String, symbol: String, color: String, sizes: [String] = []) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.price = price
        self.compareAtPrice = compareAtPrice
        self.rating = rating
        self.reviewCount = reviewCount
        self.summary = summary
        self.symbol = symbol
        self.color = color
        self.sizes = sizes
    }

    // Screens get `compareAtPrice` as 0 when there's no sale, plus `onSale`, so they never read a missing field.
    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, price, compareAtPrice, rating, reviewCount, summary, symbol, color, sizes, onSale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        category = try container.decode(String.self, forKey: .category)
        price = try container.decode(Decimal.self, forKey: .price)
        compareAtPrice = try container.decodeIfPresent(Decimal.self, forKey: .compareAtPrice).flatMap { $0 > 0 ? $0 : nil }
        rating = try container.decode(Double.self, forKey: .rating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
        summary = try container.decode(String.self, forKey: .summary)
        symbol = try container.decode(String.self, forKey: .symbol)
        color = try container.decode(String.self, forKey: .color)
        sizes = try container.decodeIfPresent([String].self, forKey: .sizes) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(brand, forKey: .brand)
        try container.encode(category, forKey: .category)
        try container.encode(price, forKey: .price)
        try container.encode(compareAtPrice ?? 0, forKey: .compareAtPrice)
        try container.encode(compareAtPrice != nil, forKey: .onSale)
        try container.encode(rating, forKey: .rating)
        try container.encode(reviewCount, forKey: .reviewCount)
        try container.encode(summary, forKey: .summary)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(color, forKey: .color)
        try container.encode(sizes, forKey: .sizes)
    }
}

public struct Category: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var symbol: String

    public init(id: String, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }
}

/// What the home screen shows. Merchandising decides it server-side.
public struct HomeFeed: Codable, Equatable, Sendable {
    public var headline: String
    public var subheadline: String
    public var categories: [Category]
    public var featured: [Product]
    public var trending: [Product]

    public init(headline: String, subheadline: String, categories: [Category], featured: [Product], trending: [Product]) {
        self.headline = headline
        self.subheadline = subheadline
        self.categories = categories
        self.featured = featured
        self.trending = trending
    }
}

public struct CartLine: Codable, Equatable, Identifiable, Sendable {
    /// Product and size: the same product in two sizes is two lines.
    public var id: String
    public var product: Product
    public var size: String
    public var quantity: Int
    public var lineTotal: Decimal { product.price * Decimal(quantity) }

    public init(product: Product, size: String, quantity: Int) {
        self.id = size.isEmpty ? product.id : "\(product.id)-\(size)"
        self.product = product
        self.size = size
        self.quantity = quantity
    }

    // Encode the computed line total too, so screens can show it without doing money math.
    enum CodingKeys: String, CodingKey { case id, product, size, quantity, lineTotal }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        product = try container.decode(Product.self, forKey: .product)
        size = try container.decode(String.self, forKey: .size)
        quantity = try container.decode(Int.self, forKey: .quantity)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(product, forKey: .product)
        try container.encode(size, forKey: .size)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(lineTotal, forKey: .lineTotal)
    }
}

public struct Promo: Codable, Equatable, Sendable {
    public var code: String
    /// Percent off the subtotal, 0–100.
    public var percentOff: Decimal

    public init(code: String, percentOff: Decimal) {
        self.code = code
        self.percentOff = percentOff
    }
}

public struct ShippingOption: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var detail: String
    public var price: Decimal

    public init(id: String, name: String, detail: String, price: Decimal) {
        self.id = id
        self.name = name
        self.detail = detail
        self.price = price
    }

    public static let all = [
        ShippingOption(id: "standard", name: "Standard", detail: "3–5 business days · free over $75", price: 0),
        ShippingOption(id: "express", name: "Express", detail: "1–2 business days", price: 12),
    ]
}

public struct Address: Codable, Equatable, Sendable {
    public var name: String
    public var street: String
    public var city: String

    public init(name: String, street: String, city: String) {
        self.name = name
        self.street = street
        self.city = city
    }
}

/// Money math lives here, natively, never in a payload.
public struct OrderTotals: Codable, Equatable, Sendable {
    public var itemCount: Int
    public var subtotal: Decimal
    public var discount: Decimal
    public var shipping: Decimal
    public var tax: Decimal
    public var total: Decimal

    public static let taxRate: Decimal = 0.08
    public static let freeShippingThreshold: Decimal = 75

    public init(lines: [CartLine], promo: Promo?, shipping option: ShippingOption?) {
        let subtotal = lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
        let discount = promo.map { Self.rounded(subtotal * $0.percentOff / 100) } ?? 0
        let qualifiesForFreeShipping = subtotal - discount >= Self.freeShippingThreshold
        let shipping = option.map { $0.id == "standard" && !qualifiesForFreeShipping ? Decimal(6) : $0.price } ?? 0
        let tax = Self.rounded((subtotal - discount) * Self.taxRate)
        itemCount = lines.reduce(0) { $0 + $1.quantity }
        self.subtotal = subtotal
        self.discount = discount
        self.shipping = shipping
        self.tax = tax
        total = subtotal - discount + shipping + tax
    }

    static func rounded(_ value: Decimal) -> Decimal {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .bankers)
        return result
    }
}

public struct Order: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var lines: [CartLine]
    public var totals: OrderTotals
    public var shipping: ShippingOption
    public var address: Address
    public var cardLast4: String
    public var estimatedDelivery: String

    public init(id: String, lines: [CartLine], totals: OrderTotals, shipping: ShippingOption, address: Address,
                cardLast4: String, estimatedDelivery: String) {
        self.id = id
        self.lines = lines
        self.totals = totals
        self.shipping = shipping
        self.address = address
        self.cardLast4 = cardLast4
        self.estimatedDelivery = estimatedDelivery
    }
}

public struct PaymentReceipt: Codable, Equatable, Sendable {
    public var authorizationID: String
    public var cardLast4: String

    public init(authorizationID: String, cardLast4: String) {
        self.authorizationID = authorizationID
        self.cardLast4 = cardLast4
    }
}
