import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection

/// The counter / conditional / to-do screen from the #4 design, driven entirely by JSON.
final class EndToEndTests: XCTestCase {

    static let payload = #"""
    {
      "state": {
        "count": 0,
        "todos": [ { "title": "Milk", "done": false } ]
      },
      "body": { "vStack": { "children": [
        { "text": { "value": { "format": ["Tapped {0} times", { "var": "count" }] } } },

        { "button": { "label": { "text": { "value": "Tap" } },
                      "action": [ { "set": "count", "to": { "add": [{ "var": "count" }, 1] } } ] } },

        { "if": { "condition": { "gte": [{ "var": "count" }, 10] },
                  "then": { "text": { "value": "Double digits!" } } } },

        { "forEach": { "items": "todos", "content":
            { "field": { "text": "item.title", "title": "To-do" } } } },

        { "ref": "footer" }
      ]}},
      "views": {
        "footer": { "text": { "value": { "format": ["{0} to-do(s)", { "count": { "var": "todos" } }] } } }
      }
    }
    """#

    func testCounterConditionalAndTodoScreen() throws {
        let payload = try JSONDecoder().decode(InjectedPayload.self, from: Data(Self.payload.utf8))
        let store = StateStore(payload.state)
        var errors: [String] = []
        store.onError = { errors.append("\($0)") }
        let screen = InjectedScreen(store: store, payload: payload)

        func texts() throws -> [String] { try screen.inspect().findAll(ViewType.Text.self).map { try $0.string() } }

        XCTAssertEqual(try texts(), ["Tapped 0 times", "Tap", "To-do", "1 to-do(s)"])

        for _ in 0..<9 { try screen.inspect().find(button: "Tap").tap() }
        XCTAssertEqual(try texts(), ["Tapped 9 times", "Tap", "To-do", "1 to-do(s)"])

        try screen.inspect().find(button: "Tap").tap()
        XCTAssertEqual(try texts(), ["Tapped 10 times", "Tap", "Double digits!", "To-do", "1 to-do(s)"])

        try screen.inspect().find(ViewType.TextField.self).setInput("Oat milk")
        XCTAssertEqual(store.root, ["count": 10, "todos": [["title": "Oat milk", "done": false]]])
        XCTAssertEqual(errors, [])
    }

    func testPayloadRoundTripsAndDefaults() throws {
        let payload = try JSONDecoder().decode(InjectedPayload.self, from: Data(Self.payload.utf8))
        let again = try JSONDecoder().decode(InjectedPayload.self, from: JSONEncoder().encode(payload))
        XCTAssertEqual(again.state, payload.state)
        XCTAssertEqual(again.views.keys.sorted(), ["footer"])

        let minimal = try JSONDecoder().decode(InjectedPayload.self, from: Data(#"{"body": {"text": {"value": "Hi"}}}"#.utf8))
        XCTAssertEqual(minimal.state, [:])
        XCTAssertTrue(minimal.views.isEmpty)
    }
}
