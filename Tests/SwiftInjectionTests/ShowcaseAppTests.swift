import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection
@testable import SwiftInjectionCore
import SwiftInjectionCompiler

/// Compiles the showcase apps' real screen sources (Examples/…/screens) and drives them with the runtime, so the
/// examples can't drift from the library.
final class ShowcaseAppTests: XCTestCase {

    private static let examples = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Examples")

    /// Compiles `screens/<screen>.swift` (with its scripts) from an example app and returns a store and screen.
    private func load(_ app: String, _ screen: String) throws -> (InjectedScreen, StateStore) {
        let screens = Self.examples.appendingPathComponent(app).appendingPathComponent("screens")
        let source = try String(contentsOf: screens.appendingPathComponent("\(screen).swift"), encoding: .utf8)
        let scripts = try? String(contentsOf: screens.appendingPathComponent("\(screen).scripts.js"), encoding: .utf8)
        let components = (try? String(contentsOf: screens.appendingPathComponent("components"), encoding: .utf8))
            .map { Set($0.split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }) } ?? []
        let result = SwiftUICompiler.compile(source: source, fileName: "\(screen).swift", scripts: scripts, components: components)
        XCTAssertEqual(result.diagnostics.map(\.description), [])
        let json = try XCTUnwrap(try result.json())
        let payload = try PayloadValidator().validate(json, signature: nil).payload
        let store = StateStore(payload: payload)
        return (InjectedScreen(store: store, payload: payload), store)
    }

    // MARK: Event RSVP (#40)

    func testEventRSVPFlow() throws {
        let (screen, store) = try load("Simple/EventRSVP", "EventScreen")
        var submitted: [RuntimeValue] = []
        store.functions["submitRSVP"] = { args, _ in submitted = args; return .null }
        func texts() throws -> [String] { try screen.inspect().findAll(ViewType.Text.self).map { try $0.string() } }

        XCTAssertTrue(try texts().contains("SwiftUI Meetup"))
        XCTAssertTrue(try texts().contains("Shipping SwiftUI without waiting on review"))
        let countdown = try texts().first { $0.hasPrefix("Starts") || $0.hasPrefix("Happening") || $0.hasPrefix("This event") }
        XCTAssertNotNil(countdown, "the countdown script should render")

        // The RSVP button stays disabled until name and email are filled in.
        XCTAssertTrue(try screen.inspect().find(button: "RSVP").isDisabled())
        let fields = try screen.inspect().findAll(ViewType.TextField.self)
        try fields[0].setInput("Ada")
        try fields[1].setInput("ada@example.com")
        XCTAssertFalse(try screen.inspect().find(button: "RSVP").isDisabled())

        try screen.inspect().find(button: "RSVP").tap()
        XCTAssertEqual(store.value(at: ["confirming"]), true)
        try screen.inspect().find(ViewType.Alert.self).actions().find(button: "Confirm").tap()

        XCTAssertEqual(store.value(at: ["isGoing"]), true)
        XCTAssertEqual(submitted, ["Ada", "ada@example.com", 0, "none", true])
        XCTAssertTrue(try texts().contains("You're going, Ada! We'll see you there."))
    }

    // MARK: Onboarding (#41)

    func testOnboardingVariantsPageThroughAndHandOff() throws {
        for (screenName, finalButton) in [("OnboardingScreen", "Get started"), ("OnboardingScreenB", "Let's go")] {
            let (screen, store) = try load("Simple/Onboarding", screenName)
            var calls: [String] = []
            store.functions["finishOnboarding"] = { args, _ in calls.append("finish:" + (args.first?.displayString ?? "")); return .null }
            store.functions["track"] = { args, _ in calls.append("track:" + (args.first?.displayString ?? "")); return .null }

            XCTAssertNoThrow(try screen.inspect().find(ViewType.TabView.self), screenName)
            try screen.inspect().find(button: "Next").tap()
            try screen.inspect().find(button: "Next").tap()
            XCTAssertEqual(store.value(at: ["page"]), 2, screenName)
            try screen.inspect().find(button: finalButton).tap()
            XCTAssertEqual(calls, ["finish:completed"], screenName)
        }
    }

    func testOnboardingSkipAndExposureTracking() throws {
        let (screen, store) = try load("Simple/Onboarding", "OnboardingScreen")
        var calls: [String] = []
        store.functions["finishOnboarding"] = { args, _ in calls.append("finish:" + (args.first?.displayString ?? "")); return .null }
        store.functions["track"] = { args, _ in calls.append("track:" + (args.first?.displayString ?? "")); return .null }

        for candidate in try screen.inspect().findAll(ViewType.AnyView.self) where (try? candidate.callOnAppear()) != nil { break }
        try screen.inspect().find(button: "Skip").tap()
        XCTAssertEqual(calls, ["track:onboarding_shown", "finish:skipped"])
    }

    // MARK: Banking (#42)

    func testBankingScreensCompile() throws {
        for screen in ["Offers", "Help", "WhatsNew", "AlertsBanner"] {
            XCTAssertNoThrow(try load("Enterprise/Banking", screen), screen)
        }
    }

    func testBankingOffersUseInjectedUserAndHostFunctions() throws {
        let (screen, store) = try load("Enterprise/Banking", "Offers")
        // Stand-ins for the design system and services RemoteBridge registers in the app.
        store.components["PrimaryButton"] = { context in
            AnyView(Button(context.prop("title") ?? "") { context.send("action") })
        }
        var calls: [String] = []
        store.functions["applyForOffer"] = { args, _ in calls.append("apply:" + (args.first?.displayString ?? "")); return .null }
        store.functions["navigate"] = { args, _ in calls.append("navigate:" + (args.first?.displayString ?? "")); return .null }
        store.functions["track"] = { args, _ in calls.append("track:" + (args.first?.displayString ?? "")); return .null }
        store.update { $0 = $0.setting(["firstName": "Alex"], at: ["user"]) }

        XCTAssertNoThrow(try screen.inspect().find(text: "Picked for you, Alex"))
        try screen.inspect().findAll(ViewType.Button.self).first { (try? $0.labelView().text().string()) == "Apply" }?.tap()
        try screen.inspect().find(button: "Start saving").tap()
        XCTAssertEqual(calls, ["apply:savings-boost", "track:spring_promo_tapped", "navigate:transfer"])

        // The app reports the result into state; the screen shows it.
        store.update { $0 = $0.setting(true, at: ["applied", "savings-boost"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "Application received"))
    }

    // MARK: Retail (#43)

    /// Records every host function a Retail screen calls, the way RemoteScreen forwards intents to TCA actions.
    private func recordIntents(_ store: StateStore, _ names: [String]) -> () -> [String] {
        var calls: [String] = []
        for name in names {
            store.functions[name] = { args, _ in
                calls.append(([name] + args.map(\.displayString)).joined(separator: ":"))
                return .null
            }
        }
        return { calls }
    }

    private func usd(_ amount: Double) -> String { amount.formatted(.currency(code: "USD")) }

    func testRetailScreensCompile() throws {
        for screen in ["Home", "Catalog", "ProductDetail", "Cart", "CheckoutReview", "OrderConfirmation", "Account"] {
            XCTAssertNoThrow(try load("Enterprise/Retail", screen), screen)
        }
    }

    func testRetailHomeRendersTheAppsFeed() throws {
        let (screen, store) = try load("Enterprise/Retail", "Home")
        let calls = recordIntents(store, ["openProduct", "openCategory", "search"])
        store.update { $0 = $0.setting(["headline": "Winter Sale", "subheadline": "Everything 40% off",
                                         "categories": [["id": "tech", "name": "Tech", "symbol": "headphones"]],
                                         "featured": [], "trending": [
                                            ["id": "mug", "name": "Stoneware Mug Set", "brand": "Hearth", "price": 32, "compareAtPrice": 0,
                                             "onSale": false, "rating": 4.7, "reviewCount": 1530, "symbol": "cup.and.saucer.fill", "color": "#6D8B74"]]],
                                        at: ["feed"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "Winter Sale"))
        XCTAssertNoThrow(try screen.inspect().find(text: usd(32)))
        XCTAssertNoThrow(try screen.inspect().find(text: "4.7"))
        try screen.inspect().find(button: "Tech").tap()
        try screen.inspect().find(button: "Stoneware Mug Set").tap()
        XCTAssertEqual(calls(), ["openCategory:tech", "openProduct:mug"])

        store.update { $0 = $0.setting(true, at: ["isLoading"]) }
        XCTAssertNoThrow(try screen.inspect().find(ViewType.ProgressView.self))
    }

    func testRetailProductDetailShowsFeatureStateAndSendsIntents() throws {
        let (screen, store) = try load("Enterprise/Retail", "ProductDetail")
        let calls = recordIntents(store, ["selectSize", "changeQuantity", "addToCart", "viewCart"])

        XCTAssertFalse(try screen.inspect().find(button: "Add to cart").isDisabled())
        XCTAssertTrue(try screen.inspect().findAll(ViewType.Button.self)[4].isDisabled(), "minus is disabled at quantity 1")
        try screen.inspect().find(button: "M").tap()
        try screen.inspect().find(button: "Add to cart").tap()
        XCTAssertEqual(calls(), ["selectSize:M", "addToCart"])

        // The feature rejects adding without a size; the screen shows what the feature decided.
        store.update { $0 = $0.setting(true, at: ["needsSize"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "Choose a size first"))
        store.update { $0 = $0.setting(true, at: ["added"]) }
        try screen.inspect().find(button: "View cart").tap()
        XCTAssertEqual(calls().last, "viewCart")
    }

    func testRetailCartShowsTotalsPromoAndEmptyState() throws {
        let (screen, store) = try load("Enterprise/Retail", "Cart")
        let calls = recordIntents(store, ["changeQuantity", "applyPromo", "removePromo", "checkout", "browse"])

        XCTAssertNoThrow(try screen.inspect().find(text: usd(230.04)))
        try screen.inspect().findAll(ViewType.TextField.self)[0].setInput("FALL20")
        try screen.inspect().find(button: "Apply").tap()
        try screen.inspect().find(button: "Checkout").tap()
        XCTAssertEqual(calls(), ["applyPromo:FALL20", "checkout"])

        store.update { $0 = $0.setting("invalid", at: ["promoStatus"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "That code isn't valid."))
        store.update { $0 = $0.setting("FALL20", at: ["promoCode"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "FALL20 applied"))

        store.update { $0 = $0.setting([], at: ["lines"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "Your cart is empty"))
        try screen.inspect().find(button: "Start shopping").tap()
        XCTAssertEqual(calls().last, "browse")
    }

    func testRetailCheckoutSendsShippingAndPay() throws {
        let (screen, store) = try load("Enterprise/Retail", "CheckoutReview")
        let calls = recordIntents(store, ["selectShipping", "pay"])
        try screen.inspect().find(button: "Express").tap()
        try screen.inspect().find(button: "Pay " + usd(160.92)).tap()
        XCTAssertEqual(calls(), ["selectShipping:express", "pay"])

        store.update { $0 = $0.setting(true, at: ["isPlacingOrder"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "Placing your order…"))
    }

    func testRetailCatalogSendsSearchesAndFilters() throws {
        let (screen, store) = try load("Enterprise/Retail", "Catalog")
        let calls = recordIntents(store, ["search", "selectCategory", "sort", "openProduct"])
        try screen.inspect().find(ViewType.TextField.self).setInput("boot")
        // `.onChange(of: query)` runs on a real render; trigger it the way SwiftUI would.
        let changed = try screen.inspect().findAll(ViewType.AnyView.self)
            .contains { (try? $0.callOnChange(newValue: RuntimeValue.string("boot"))) != nil }
        XCTAssertTrue(changed)
        try screen.inspect().find(button: "Shoes").tap()
        try screen.inspect().find(button: "Price ↑").tap()
        XCTAssertEqual(calls(), ["search:boot", "selectCategory:shoes", "sort:priceLow"])
        XCTAssertNoThrow(try screen.inspect().find(text: "2 results"))
    }

    func testRetailAccountShowsProfileAndOrders() throws {
        let (screen, store) = try load("Enterprise/Retail", "Account")
        let calls = recordIntents(store, ["startShopping"])
        store.update { $0 = $0.setting(["name": "Ada Obi", "email": "ada@example.com", "cardLast4": "1881",
                                         "address": ["street": "1 Main St", "city": "Lagos"]], at: ["profile"]) }
        XCTAssertNoThrow(try screen.inspect().find(text: "Ada Obi"))
        XCTAssertNoThrow(try screen.inspect().find(text: "Visa •••• 1881"))
        XCTAssertNoThrow(try screen.inspect().find(text: "Order NW-48213"))
        XCTAssertNoThrow(try screen.inspect().find(text: usd(181.48)))

        store.update { $0 = $0.setting([], at: ["orders"]) }
        try screen.inspect().find(button: "Start shopping").tap()
        XCTAssertEqual(calls(), ["startShopping"])
    }
}
