import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection

final class LeafComponentTests: XCTestCase {

    // MARK: decoding

    func testViewDecodingUsesCompactFormAndDefaults() throws {
        let view = try JSONDecoder().decode(InjectedView.self, from: Data(#"{"text": {"value": "Hi"}}"#.utf8))
        guard case let .text(store) = view else { return XCTFail("\(view)") }
        XCTAssertEqual(store.id, "")
        XCTAssertTrue(store.modifiers.isEmpty)
        XCTAssertEqual(store.value, "Hi")

        let reencoded = String(decoding: try JSONEncoder().encode(view), as: UTF8.self)
        XCTAssertTrue(reencoded.hasPrefix(#"{"text":{"#), reencoded)
    }

    func testViewDecodingRejectsUnknownAndAmbiguousComponents() {
        XCTAssertThrowsError(try JSONDecoder().decode(InjectedView.self, from: Data(#"{"marquee": {}}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(InjectedView.self, from: Data(#"{"text": {"value": "a"}, "spacer": {}}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(InjectedView.self, from: Data(#"{"text": {}}"#.utf8)))  // value is required
    }

    func testModifiersAccessorReadsAndWritesEveryComponent() throws {
        var view = try JSONDecoder().decode(InjectedView.self, from: Data(#"{"spacer": {"modifiers": [{"bold": {}}]}}"#.utf8))
        XCTAssertEqual(view.modifiers.count, 1)
        view.modifiers.append(.italic())
        XCTAssertEqual(view.modifiers.count, 2)
    }

    // MARK: rendering

    func testTextEvaluatesItsValue() throws {
        let screen = try RenderedScreen(#"{"text": {"value": {"format": ["Hi {0}", {"var": "name"}]}}}"#, state: ["name": "Ada"])
        XCTAssertEqual(try screen.texts(), ["Hi Ada"])
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testTextUpdatesWhenStateChanges() throws {
        let screen = try RenderedScreen(#"{"text": {"value": {"var": "count"}}}"#, state: ["count": 1])
        XCTAssertEqual(try screen.texts(), ["1"])
        screen.store.update { $0 = $0.setting(2, at: ["count"]) }
        XCTAssertEqual(try screen.texts(), ["2"])
    }

    func testTextReportsEvaluationErrors() throws {
        let screen = try RenderedScreen(#"{"text": {"value": {"var": "missing"}}}"#)
        XCTAssertEqual(try screen.texts(), [""])
        // Reported on every evaluation of the body, so compare unique errors.
        XCTAssertEqual(Set(screen.reportedErrors), ["Unknown variable 'missing'"])
    }

    func testImageSourcesInPriorityOrder() throws {
        let system = try RenderedScreen(#"{"image": {"systemName": {"var": "icon"}, "name": "ignored"}}"#, state: ["icon": "star.fill"])
        XCTAssertEqual(try system.inspect().find(ViewType.Image.self).actualImage().name(), "star.fill")

        let named = try RenderedScreen(#"{"image": {"name": "logo"}}"#)
        XCTAssertEqual(try named.inspect().find(ViewType.Image.self).actualImage().name(), "logo")

        let remote = try RenderedScreen(#"{"image": {"url": "https://example.com/a.png", "systemName": "ignored"}}"#)
        XCTAssertNoThrow(try remote.inspect().find(ViewType.AsyncImage.self))

        let fallback = try RenderedScreen(#"{"image": {}}"#)
        XCTAssertEqual(try fallback.inspect().find(ViewType.Image.self).actualImage().name(), "photo")
    }

    func testLabel() throws {
        let screen = try RenderedScreen(#"{"label": {"title": {"var": "title"}, "systemImage": "gear"}}"#, state: ["title": "Settings"])
        let label = try screen.inspect().find(ViewType.Label.self)
        XCTAssertEqual(try label.title().text().string(), "Settings")
        XCTAssertEqual(try label.icon().image().actualImage().name(), "gear")
    }

    func testColorAndShapesRenderWithoutErrors() throws {
        for json in [
            #"{"color": {"color": {"var": "tint"}}}"#,
            #"{"rectangle": {"modifiers": [{"foregroundColor": {"color": {"var": "tint"}}}]}}"#,
            #"{"circle": {}}"#,
            #"{"ellipse": {"modifiers": [{"path": {"width": 10, "height": 5}}]}}"#,
            #"{"capsule": {"style": "circular"}}"#,
            #"{"roundedRectangle": {"cornerRadius": {"var": "radius"}, "style": "continuous"}}"#,
            #"{"spacer": {"minLength": 8}}"#,
            #"{"divider": {}}"#,
        ] {
            let screen = try RenderedScreen(json, state: ["tint": "#3366FF", "radius": 12])
            XCTAssertNoThrow(try screen.inspect(), json)
            XCTAssertEqual(screen.reportedErrors, [], json)
        }
    }

    func testViewReferenceRendersContainerView() throws {
        let screen = try RenderedScreen(#"{"ref": "greeting"}"#, state: ["name": "Ada"],
                                        views: [#"{"text": {"id": "greeting", "value": {"var": "name"}}}"#])
        XCTAssertEqual(try screen.texts(), ["Ada"])
    }

    // MARK: modifiers on migrated components use the real store

    func testAlertButtonRunsActionsAgainstStore() throws {
        let screen = try RenderedScreen(#"""
        {"text": {"value": "Item", "modifiers": [
          {"alert": {"isPresented": "confirming", "alert": {
            "title": "Delete?",
            "buttons": [{"label": "Delete", "role": "destructive",
                         "action": [{"set": "deleted", "to": true}, {"set": "confirming", "to": false}]}]}}}
        ]}}
        """#, state: ["confirming": true, "deleted": false])

        let alert = try screen.inspect().find(ViewType.Alert.self)
        XCTAssertEqual(try alert.title().string(), "Delete?")
        try alert.actions().find(button: "Delete").tap()
        XCTAssertEqual(screen.store.root, ["confirming": false, "deleted": true])
    }
}
