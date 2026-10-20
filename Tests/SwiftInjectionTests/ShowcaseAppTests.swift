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
        let result = SwiftUICompiler.compile(source: source, fileName: "\(screen).swift", scripts: scripts)
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
}
