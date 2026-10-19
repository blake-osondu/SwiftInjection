import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection
@testable import SwiftInjectionCore

/// A native view standing in for something an app would register (a branded card, a chart...).
private struct Badge: View {
    let label: String
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button("\(label): \(count)", action: onTap)
    }
}

final class CustomComponentTests: XCTestCase {

    private let badge: InjectedComponent = { context in
        AnyView(Badge(label: context.prop("label") ?? "?", count: context.prop("count") ?? 0, onTap: { context.send("tap") }))
    }

    private func screen(_ json: String, state: RuntimeValue) throws -> RenderedScreen {
        let screen = try RenderedScreen(json, state: state)
        screen.store.components["badge"] = badge
        return screen
    }

    func testRendersWithEvaluatedPropsAndUpdates() throws {
        let screen = try screen(#"""
        {"custom": {"name": "badge", "props": {"label": "Inbox", "count": {"var": "unread"}}}}
        """#, state: ["unread": 3])
        XCTAssertNoThrow(try screen.inspect().find(button: "Inbox: 3"))

        screen.store.update { $0 = $0.setting(4, at: ["unread"]) }
        XCTAssertNoThrow(try screen.inspect().find(button: "Inbox: 4"))
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testEventsRunPayloadActions() throws {
        let screen = try screen(#"""
        {"custom": {"name": "badge", "props": {"label": "Inbox", "count": {"var": "unread"}},
                    "on": {"tap": [{"set": "unread", "to": 0}, {"set": "opened", "to": true}]}}}
        """#, state: ["unread": 3])
        try screen.inspect().find(button: "Inbox: 3").tap()
        XCTAssertEqual(screen.store.root, ["unread": 0, "opened": true])
    }

    func testWorksInsideForEachWithItemProps() throws {
        let screen = try screen(#"""
        {"vStack": {"children": [{"forEach": {"items": "folders", "content":
          {"custom": {"name": "badge", "props": {"label": {"var": "item.name"}, "count": {"var": "item.unread"}},
                      "on": {"tap": [{"set": "item.unread", "to": 0}]}}}}}]}}
        """#, state: ["folders": [["name": "Inbox", "unread": 2], ["name": "Spam", "unread": 9]]])
        XCTAssertEqual(try screen.inspect().findAll(ViewType.Button.self).map { try $0.labelView().text().string() },
                       ["Inbox: 2", "Spam: 9"])

        try screen.inspect().find(button: "Spam: 9").tap()
        XCTAssertEqual(screen.store.value(at: ["folders", "1", "unread"]), 0)
        XCTAssertEqual(screen.store.value(at: ["folders", "0", "unread"]), 2)
    }

    func testModifiersApplyAndFailedPropsAreReported() throws {
        let screen = try screen(#"""
        {"custom": {"name": "badge", "props": {"label": "x", "count": {"var": "missing"}},
                    "modifiers": [{"padding": {"length": 4}}]}}
        """#, state: [:])
        XCTAssertNoThrow(try screen.inspect().find(button: "x: 0"))  // failed prop falls back in the builder
        XCTAssertEqual(Set(screen.reportedErrors), ["Unknown variable 'missing'"])
    }

    func testUnregisteredComponentIsReported() throws {
        let screen = try RenderedScreen(#"{"custom": {"name": "chart"}}"#)
        XCTAssertThrowsError(try screen.inspect().find(ViewType.Button.self))
        XCTAssertEqual(Set(screen.reportedErrors), [EvaluationError.unknownFunction("component 'chart' (register it in StateStore.components)").description])
    }

    func testDefaultComponentsApplyToNewStores() {
        let previous = StateStore.defaultComponents
        defer { StateStore.defaultComponents = previous }
        StateStore.defaultComponents["badge"] = badge
        XCTAssertNotNil(StateStore().components["badge"])
    }

    func testCustomDecodesAndRoundTrips() throws {
        let json = #"{"custom": {"name": "badge", "props": {"count": {"add": [{"var": "a"}, 1]}}, "on": {"tap": [{"set": "a", "to": 0}]}}}"#
        let view = try JSONDecoder().decode(InjectedView.self, from: Data(json.utf8))
        guard case let .custom(store) = view else { return XCTFail("\(view)") }
        XCTAssertEqual(store.name, "badge")
        XCTAssertEqual(store.props["count"], .operation(.add, [.var("a"), 1]))
        XCTAssertEqual(store.on["tap"], [.set(path: "a", to: 0)])
        let again = try JSONDecoder().decode(InjectedView.self, from: JSONEncoder().encode(view))
        guard case let .custom(roundTripped) = again else { return XCTFail() }
        XCTAssertEqual(roundTripped.props, store.props)
    }
}
