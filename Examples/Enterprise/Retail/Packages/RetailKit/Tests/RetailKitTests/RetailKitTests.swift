import XCTest
import ComposableArchitecture
@testable import Models
@testable import Clients
@testable import Payment
@testable import Features
@testable import RemoteScreens

@MainActor
final class RetailKitTests: XCTestCase {
    let puffer = Catalog.products.first { $0.id == "puffer" }!   // $149, sizes
    let mug = Catalog.products.first { $0.id == "mug" }!         // $32, no sizes

    // MARK: Money

    func testTotalsApplyPromoFreeShippingAndTax() {
        let small = OrderTotals(lines: [CartLine(product: mug, size: "", quantity: 1)], promo: nil, shipping: ShippingOption.all[0])
        XCTAssertEqual(small.subtotal, 32)
        XCTAssertEqual(small.shipping, 6, "standard shipping is charged under $75")
        XCTAssertEqual(small.tax, Decimal(string: "2.56"))
        XCTAssertEqual(small.total, Decimal(string: "40.56"))

        let promo = Promo(code: "FALL20", percentOff: 20)
        let big = OrderTotals(lines: [CartLine(product: puffer, size: "M", quantity: 1)], promo: promo, shipping: ShippingOption.all[0])
        XCTAssertEqual(big.discount, Decimal(string: "29.8"))
        XCTAssertEqual(big.shipping, 0)
        XCTAssertEqual(big.tax, Decimal(string: "9.54"))
        XCTAssertEqual(big.total, Decimal(string: "128.74"))

        let express = OrderTotals(lines: [CartLine(product: puffer, size: "M", quantity: 1)], promo: nil, shipping: ShippingOption.all[1])
        XCTAssertEqual(express.shipping, 12)
    }

    func testProductsEncodeForScreensWithoutMissingFields() throws {
        let data = try JSONEncoder().encode(mug)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["compareAtPrice"] as? Double, 0)
        XCTAssertEqual(json["onSale"] as? Bool, false)
        XCTAssertEqual(try JSONDecoder().decode(Product.self, from: data), mug)
        XCTAssertEqual(try JSONDecoder().decode(Product.self, from: JSONEncoder().encode(puffer)), puffer)
    }

    // MARK: Product

    func testProductRequiresASizeAndClampsQuantity() async {
        let store = TestStore(initialState: ProductFeature.State(product: puffer)) { ProductFeature() }
        await store.send(.addToCartTapped) { $0.needsSize = true }
        await store.send(.quantityChanged(by: -1))
        await store.send(.quantityChanged(by: 20)) { $0.quantity = 10 }
        await store.send(.sizeTapped("XXL"))  // not a size this product has
        await store.send(.sizeTapped("M")) {
            $0.selectedSize = "M"
            $0.needsSize = false
        }
        await store.send(.addToCartTapped) { $0.added = true }
        await store.receive(\.delegate.addToCart)
    }

    // MARK: Cart

    func testCartMergesLinesAndRemovesAtZero() async {
        var state = CartFeature.State()
        state.add(puffer, size: "M", quantity: 1)
        state.add(puffer, size: "M", quantity: 2)
        state.add(puffer, size: "L", quantity: 1)
        XCTAssertEqual(state.lines.map(\.id), ["puffer-M", "puffer-L"])
        XCTAssertEqual(state.lines[id: "puffer-M"]?.quantity, 3)

        let store = TestStore(initialState: state) { CartFeature() }
        await store.send(.quantityChanged(lineID: "puffer-L", by: -1)) { $0.lines.remove(id: "puffer-L") }
        await store.send(.quantityChanged(lineID: "puffer-M", by: 20)) { $0.lines[id: "puffer-M"]?.quantity = 10 }
        await store.send(.removeTapped(lineID: "puffer-M")) { $0.lines = [] }
        await store.send(.checkoutTapped)  // nothing to check out
    }

    func testPromoCodes() async {
        let store = TestStore(initialState: CartFeature.State()) { CartFeature() } withDependencies: {
            $0.orders.validatePromo = { code in code == "FALL20" ? Promo(code: "FALL20", percentOff: 20) : nil }
        }
        await store.send(.applyPromoTapped("NOPE")) { $0.promoStatus = .checking }
        await store.receive(\.promoValidated) { $0.promoStatus = .invalid }
        await store.send(.applyPromoTapped("FALL20")) { $0.promoStatus = .checking }
        await store.receive(\.promoValidated) {
            $0.promo = Promo(code: "FALL20", percentOff: 20)
            $0.promoStatus = .none
        }
        await store.send(.removePromoTapped) { $0.promo = nil }
    }

    // MARK: Catalog

    func testSearchIsDebouncedAndCategoriesToggle() async {
        let clock = TestClock()
        let store = TestStore(initialState: CatalogFeature.State()) { CatalogFeature() } withDependencies: {
            $0.continuousClock = clock
            $0.catalog.search = { query, category, sort in Catalog.search(query, category: category, sort: sort) }
        }
        await store.send(.queryChanged("bo")) {
            $0.query = "bo"
            $0.isSearching = true
        }
        await store.send(.queryChanged("boot")) { $0.query = "boot" }
        await clock.advance(by: .milliseconds(250))
        await store.receive(\.resultsLoaded) {
            $0.isSearching = false
            $0.hasSearched = true
            $0.results = [self.chelsea]
        }
        await store.send(.categoryTapped("bags")) {
            $0.category = "bags"
            $0.isSearching = true
        }
        await store.receive(\.resultsLoaded) {
            $0.isSearching = false
            $0.results = []
        }
        await store.send(.categoryTapped("bags")) {
            $0.category = nil
            $0.isSearching = true
        }
        await store.receive(\.resultsLoaded) {
            $0.isSearching = false
            $0.results = [self.chelsea]
        }
    }

    var chelsea: Product { Catalog.products.first { $0.id == "chelsea" }! }

    // MARK: Checkout and payment

    func testPayingPlacesTheOrder() async {
        let receipt = PaymentReceipt(authorizationID: "AUTH-1", cardLast4: "4242")
        let lines = [CartLine(product: puffer, size: "M", quantity: 1)]
        let store = TestStore(initialState: CheckoutFeature.State(lines: lines, promo: nil, address: CustomerProfile.demo.address,
                                                                  cardLast4: "4242")) { CheckoutFeature() } withDependencies: {
            $0.payments.authorize = { _ in receipt }
            $0.orders.place = { lines, shipping, address, receipt, totals in
                Order(id: "NW-1", lines: lines, totals: totals, shipping: shipping, address: address, cardLast4: receipt.cardLast4,
                      estimatedDelivery: "Friday")
            }
        }
        await store.send(.shippingTapped("express")) { $0.shippingID = "express" }
        XCTAssertEqual(store.state.shippingOptions.map(\.price), [0, 12])
        await store.send(.payTapped) { $0.payment = PaymentFeature.State(amount: Decimal(string: "172.92")!, cardLast4: "4242") }
        await store.send(\.payment.confirmTapped) { $0.payment?.status = .authorizing }
        await store.receive(\.payment.authorizationFinished)
        await store.receive(\.payment.delegate.authorized) { $0.isPlacingOrder = true }
        await store.receive(\.payment.dismiss) { $0.payment = nil }
        await store.receive(\.orderPlaced) { $0.isPlacingOrder = false }
        await store.receive(\.delegate.orderPlaced)
    }

    func testDeclinedPaymentStaysOnTheSheet() async {
        let store = TestStore(initialState: PaymentFeature.State(amount: 5_000, cardLast4: "4242")) { PaymentFeature() } withDependencies: {
            $0.payments.authorize = { _ in throw PaymentError("Declined") }
        }
        await store.send(.confirmTapped) { $0.status = .authorizing }
        await store.receive(\.authorizationFinished) { $0.status = .declined("Declined") }
    }

    // MARK: The whole app

    func testShoppingThroughToConfirmation() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.payments.authorize = { _ in PaymentReceipt(authorizationID: "AUTH-1", cardLast4: "4242") }
            $0.orders.place = { lines, shipping, address, receipt, totals in
                Order(id: "NW-1", lines: lines, totals: totals, shipping: shipping, address: address, cardLast4: receipt.cardLast4,
                      estimatedDelivery: "Friday")
            }
        }
        store.exhaustivity = .off

        await store.send(.home(.delegate(.openProduct(puffer)))) { $0.shopPath[id: 0] = .product(ProductFeature.State(product: self.puffer)) }
        await store.send(\.shopPath[id: 0].product.sizeTapped, "M")
        await store.send(\.shopPath[id: 0].product.addToCartTapped)
        await store.receive(\.shopPath[id: 0].product.delegate.addToCart) {
            $0.cart.lines = [CartLine(product: self.puffer, size: "M", quantity: 1)]
        }
        await store.send(\.shopPath[id: 0].product.viewCartTapped)
        await store.receive(\.shopPath[id: 0].product.delegate.viewCart) { $0.tab = .cart }

        await store.send(\.cart.checkoutTapped)
        await store.receive(\.cart.delegate.checkout)
        XCTAssertEqual(store.state.cartPath.count, 1)
        await store.send(\.cartPath[id: 1].checkout.payTapped)
        await store.send(\.cartPath[id: 1].checkout.payment.confirmTapped)
        await store.receive(\.cartPath[id: 1].checkout.delegate.orderPlaced)
        XCTAssertEqual(store.state.orders.map(\.id), ["NW-1"])
        XCTAssertTrue(store.state.cart.lines.isEmpty)
        guard case .confirmation? = store.state.cartPath.last else { return XCTFail("expected the confirmation") }
        XCTAssertEqual(store.state.cartPath.count, 1, "checkout is replaced, so Back can't return to it")

        let confirmationID = store.state.cartPath.ids.last!
        await store.send(\.cartPath[id: confirmationID].confirmation.continueShoppingTapped)
        await store.receive(\.cartPath[id: confirmationID].confirmation.delegate.continueShopping) {
            $0.cartPath = StackState()
            $0.shopPath = StackState()
            $0.tab = .shop
        }
    }

    // MARK: Remote screen arguments

    func testRemoteArguments() {
        let arguments = RemoteArguments([.string("puffer-M"), .number(-1), .number(2.5)])
        XCTAssertEqual(arguments.string(0), "puffer-M")
        XCTAssertEqual(arguments.int(1), -1)
        XCTAssertEqual(arguments.string(1), "-1")
        XCTAssertNil(arguments.int(2))
        XCTAssertEqual(arguments.string(5), "")
    }
}
