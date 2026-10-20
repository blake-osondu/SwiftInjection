import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection
@testable import SwiftInjectionCore

final class InputComponentTests: XCTestCase {

    func testButtonRunsItsActionsAndTheUIUpdates() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [
          {"text": {"value": {"format": ["Tapped {0} times", {"var": "count"}]}}},
          {"button": {"title": "Tap", "action": [{"set": "count", "to": {"add": [{"var": "count"}, 1]}}]}}
        ]}}
        """#, state: ["count": 0])
        for _ in 0..<3 {
            try screen.inspect().find(button: "Tap").tap()
        }
        XCTAssertEqual(screen.store.root, ["count": 3])
        XCTAssertEqual(try screen.inspect().find(ViewType.Text.self).string(), "Tapped 3 times")
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testButtonWithCustomLabelAndRole() throws {
        let screen = try RenderedScreen(#"""
        {"button": {"role": "destructive", "label": {"label": {"title": "Delete", "systemImage": "trash"}}, "action": [{"set": "deleted", "to": true}]}}
        """#)
        let button = try screen.inspect().find(ViewType.Button.self)
        XCTAssertEqual(try button.role(), .destructive)
        try button.tap()
        XCTAssertEqual(screen.store.root, ["deleted": true])
    }

    func testTextFieldReadsAndWritesItsPathAndSubmits() throws {
        let screen = try RenderedScreen(#"""
        {"field": {"text": "form.email", "title": "Email", "onSubmit": [{"set": "submitted", "to": {"var": "form.email"}}]}}
        """#, state: ["form": ["email": "a@b.co"]])
        let field = try screen.inspect().find(ViewType.TextField.self)
        XCTAssertEqual(try field.labelView().text().string(), "Email")
        XCTAssertEqual(try field.input(), "a@b.co")

        try field.setInput("ada@example.com")
        try screen.inspect().find(ViewType.TextField.self).callOnSubmit()
        XCTAssertEqual(screen.store.root, ["form": ["email": "ada@example.com"], "submitted": "ada@example.com"])
    }

    func testSecureFieldWritesItsPath() throws {
        let screen = try RenderedScreen(#"{"secureField": {"text": "password", "title": "Password"}}"#)
        try screen.inspect().find(ViewType.SecureField.self).setInput("hunter2")
        XCTAssertEqual(screen.store.root, ["password": "hunter2"])
    }

    func testPickerOptionsAndSelection() throws {
        let screen = try RenderedScreen(#"""
        {"picker": {"title": "Size", "selection": "order.size", "items": "sizes",
                    "content": {"text": {"value": {"format": ["{0}. {1}", {"add": [{"var": "index"}, 1]}, {"var": "item.label"}]}}},
                    "value": {"var": "item.id"}}}
        """#, state: ["sizes": [["id": "s", "label": "Small"], ["id": "l", "label": "Large"]], "order": ["size": "s"]])
        let picker = try screen.inspect().find(ViewType.Picker.self)
        XCTAssertEqual(try picker.findAll(ViewType.Text.self).map { try $0.string() }, ["1. Small", "2. Large", "Size"])

        try picker.select(value: RuntimeValue.string("l"))
        XCTAssertEqual(screen.store.value(at: ["order", "size"]), "l")
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testPickerWithPlainItems() throws {
        let screen = try RenderedScreen(#"{"picker": {"selection": "color", "items": "colors"}}"#, state: ["colors": ["red", "green"], "color": "red"])
        let picker = try screen.inspect().find(ViewType.Picker.self)
        XCTAssertEqual(try picker.findAll(ViewType.Text.self).map { try $0.string() }.prefix(2), ["red", "green"])
        try picker.select(value: RuntimeValue.string("green"))
        XCTAssertEqual(screen.store.value(at: ["color"]), "green")
    }

    func testDatePickerStoresISO8601() throws {
        let screen = try RenderedScreen(#"{"datePicker": {"title": "Due", "selection": "due", "components": ["date"]}}"#,
                                        state: ["due": "2026-01-02T03:04:05Z"])
        let picker = try screen.inspect().find(ViewType.DatePicker.self)
        XCTAssertEqual(try picker.labelView().text().string(), "Due")
        try picker.select(date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(screen.store.value(at: ["due"]), "1970-01-01T00:00:00Z")
    }

    func testDateConversion() {
        XCTAssertEqual(Date(runtimeValue: "1970-01-01T00:00:10Z"), Date(timeIntervalSince1970: 10))
        XCTAssertEqual(Date(runtimeValue: "1970-01-01T00:00:10.500Z"), Date(timeIntervalSince1970: 10.5))
        XCTAssertEqual(Date(runtimeValue: 10), Date(timeIntervalSince1970: 10))
        XCTAssertNil(Date(runtimeValue: "next tuesday"))
    }

    func testProgressView() throws {
        let determinate = try RenderedScreen(#"{"progressView": {"title": "Upload", "value": {"var": "done"}, "total": 4}}"#, state: ["done": 1])
        XCTAssertEqual(try determinate.inspect().find(ViewType.ProgressView.self).fractionCompleted(), 0.25)
        XCTAssertEqual(try determinate.texts(), ["Upload"])

        let indeterminate = try RenderedScreen(#"{"progressView": {}}"#)
        XCTAssertNil(try indeterminate.inspect().find(ViewType.ProgressView.self).fractionCompleted())
    }

    // MARK: event modifiers

    func testOnAppearAndOnTapGesture() throws {
        let screen = try RenderedScreen(#"""
        {"text": {"value": "Hi", "modifiers": [
          {"onAppear": {"do": [{"set": "appeared", "to": true}]}},
          {"onTapGesture": {"do": [{"set": "taps", "to": {"add": [{"var": ["taps", 0]}, 1]}}]}}
        ]}}
        """#)
        try screen.callModifier { try $0.callOnAppear() }
        try screen.callModifier { try $0.callOnTapGesture() }
        XCTAssertEqual(screen.store.root, ["appeared": true, "taps": 1])
    }

    func testOnChange() throws {
        let screen = try RenderedScreen(#"""
        {"text": {"value": "Hi", "modifiers": [
          {"onChange": {"of": {"var": "query"}, "do": [{"set": "searches", "to": {"add": [{"var": "searches"}, 1]}}]}}
        ]}}
        """#, state: ["query": "", "searches": 0])
        try screen.callModifier { try $0.callOnChange(newValue: RuntimeValue.string("a")) }
        XCTAssertEqual(screen.store.value(at: ["searches"]), 1)
    }
}
