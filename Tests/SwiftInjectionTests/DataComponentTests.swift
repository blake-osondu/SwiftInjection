import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection

final class DataComponentTests: XCTestCase {

    // MARK: if

    func testIfElseFollowsState() throws {
        let screen = try RenderedScreen(#"""
        {"if": {"condition": {"gte": [{"var": "count"}, 10]},
                "then": {"text": {"value": "Double digits!"}},
                "else": {"text": {"value": "Keep going"}}}}
        """#, state: ["count": 9])
        XCTAssertEqual(try screen.texts(), ["Keep going"])
        screen.store.update { $0 = $0.setting(10, at: ["count"]) }
        XCTAssertEqual(try screen.texts(), ["Double digits!"])
    }

    func testIfWithoutElseRendersNothingWhenFalse() throws {
        let screen = try RenderedScreen(#"{"if": {"condition": false, "then": {"text": {"value": "hidden"}}}}"#)
        XCTAssertEqual(try screen.texts(), [])
    }

    // MARK: forEach

    static let todos: RuntimeValue = ["todos": [
        ["id": "a", "title": "Milk", "done": false],
        ["id": "b", "title": "Eggs", "done": false],
    ]]

    func testForEachRendersItemsWithLocals() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [{"forEach": {"items": "todos", "identity": {"var": "item.id"},
          "content": {"text": {"value": {"format": ["{0}: {1}", {"var": "index"}, {"var": "item.title"}]}}}}}]}}
        """#, state: Self.todos)
        XCTAssertEqual(try screen.texts(), ["0: Milk", "1: Eggs"])
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testFieldInsideForEachEditsItsOwnRow() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [{"forEach": {"items": "todos", "content": {"field": {"text": "item.title"}}}}]}}
        """#, state: Self.todos)
        let fields = try screen.inspect().findAll(ViewType.TextField.self)
        XCTAssertEqual(try fields.map { try $0.input() }, ["Milk", "Eggs"])

        try fields[1].setInput("Oat milk")
        XCTAssertEqual(screen.store.value(at: ["todos", "1", "title"]), "Oat milk")
        XCTAssertEqual(screen.store.value(at: ["todos", "0", "title"]), "Milk")
    }

    func testButtonInsideForEachActsOnItsItem() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [{"forEach": {"items": "todos", "itemName": "todo",
          "content": {"button": {"title": {"var": "todo.title"}, "action": [{"set": "todo.done", "to": {"not": {"var": "todo.done"}}}]}}}}]}}
        """#, state: Self.todos)
        try screen.inspect().find(button: "Eggs").tap()
        XCTAssertEqual(screen.store.value(at: ["todos", "1", "done"]), true)
        XCTAssertEqual(screen.store.value(at: ["todos", "0", "done"]), false)
    }

    func testNestedForEach() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [{"forEach": {"items": "groups", "itemName": "group", "content":
          {"vStack": {"children": [{"forEach": {"items": "group.items", "content": {"text": {"value": {"var": "item"}}}}}]}}}}]}}
        """#, state: ["groups": [["items": ["a", "b"]], ["items": ["c"]]]])
        XCTAssertEqual(try screen.texts(), ["a", "b", "c"])
    }

    func testForEachOverNonArrayReportsError() throws {
        let screen = try RenderedScreen(#"{"vStack": {"children": [{"forEach": {"items": "name", "content": {"text": {"value": "x"}}}}]}}"#,
                                        state: ["name": "Ada"])
        XCTAssertEqual(try screen.texts(), [])
        XCTAssertEqual(Set(screen.reportedErrors), [EvaluationError.typeMismatch(op: "items", expected: "array", got: "string").description])
    }

    // MARK: list, table, geometry

    func testListCombinesStaticAndDataRows() throws {
        let screen = try RenderedScreen(#"""
        {"list": {"children": [{"text": {"value": "Header row"}}], "items": "todos",
                  "content": {"text": {"value": {"var": "item.title"}}}}}
        """#, state: Self.todos)
        XCTAssertEqual(try screen.texts(), ["Header row", "Milk", "Eggs"])
    }

    func testTableRendersWithoutErrors() throws {
        let screen = try RenderedScreen(#"""
        {"table": {"items": "todos", "columns": [
          {"title": "Title", "content": {"text": {"value": {"var": "item.title"}}}},
          {"title": "Done", "content": {"text": {"value": {"var": "item.done"}}}}]}}
        """#, state: Self.todos)
        XCTAssertNoThrow(try screen.inspect())
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testGeometryValue() {
        let value = GeometryReaderInsertable.geometry(CGSize(width: 320, height: 480), EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0))
        XCTAssertEqual(value.value(at: ["width"]), 320)
        XCTAssertEqual(value.value(at: ["safeArea", "bottom"]), 34)
    }
}
