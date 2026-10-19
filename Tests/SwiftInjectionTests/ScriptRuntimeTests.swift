import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection

final class ScriptRuntimeTests: XCTestCase {

    private func runtime(_ scripts: [String: String]) throws -> ScriptRuntime {
        let runtime = ScriptRuntime()
        for (name, source) in scripts { try runtime.define(name, source: source) }
        return runtime
    }

    private func call(_ runtime: ScriptRuntime, _ name: String, _ args: [RuntimeValue], state: RuntimeValue = [:]) throws -> RuntimeValue {
        var state = state
        return try runtime.call(name, args, state: &state)
    }

    // MARK: runtime

    func testCallsFunctionsAndConvertsValues() throws {
        let runtime = try runtime([
            "add": "(a, b) => a + b",
            "describe": "function (user) { return { name: user.name.toUpperCase(), tags: user.tags.length, admin: !user.admin, none: null } }",
            "nothing": "() => undefined",
        ])
        XCTAssertEqual(try call(runtime, "add", [1, 2]), 3)
        XCTAssertEqual(try call(runtime, "describe", [["name": "ada", "tags": ["a", "b"], "admin": false]]),
                       ["name": "ADA", "tags": 2, "admin": true, "none": nil])
        XCTAssertEqual(try call(runtime, "nothing", []), nil)
    }

    func testStateGetAndSet() throws {
        let runtime = try runtime([
            "addTodo": "function (title) { const todos = state.get('todos'); todos.push({ title: title, done: false }); state.set('todos', todos); return todos.length }",
        ])
        var state: RuntimeValue = ["todos": [["title": "Milk", "done": false]]]
        XCTAssertEqual(try runtime.call("addTodo", ["Bread"], state: &state), 2)
        XCTAssertEqual(state, ["todos": [["title": "Milk", "done": false], ["title": "Bread", "done": false]]])
    }

    func testExceptionsBecomeScriptErrors() throws {
        let runtime = try runtime(["boom": "function () { throw new Error('nope') }"])
        XCTAssertThrowsError(try call(runtime, "boom", [])) { error in
            guard case .script(let message)? = error as? EvaluationError else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("nope"), message)
        }
        // The context stays usable after an exception.
        try runtime.define("ok", source: "() => 'fine'")
        XCTAssertEqual(try call(runtime, "ok", []), "fine")
    }

    func testDefineRejectsSyntaxErrorsAndNonFunctions() {
        let runtime = ScriptRuntime()
        XCTAssertThrowsError(try runtime.define("broken", source: "function ( {")) {
            guard case .script? = $0 as? EvaluationError else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try runtime.define("answer", source: "42")) {
            XCTAssertEqual($0 as? EvaluationError, .script("'answer' is not a function"))
        }
        XCTAssertEqual(runtime.functionNames, [])
    }

    func testConsoleLogGoesToStore() throws {
        let payload = InjectedPayload(body: .empty(), scripts: ["hello": "(name) => { console.log('hi', name); return 1 }"])
        let store = StateStore(payload: payload)
        var logs: [String] = []
        store.onLog = { logs.append($0) }
        try StateScope(store: store).performThrowing([.call(name: "hello", args: ["Ada"])])
        XCTAssertEqual(logs, ["hi Ada"])
    }

    // MARK: through the store

    func testActionCallWritesStateInsideTheTransaction() throws {
        let store = StateStore(payload: InjectedPayload(
            state: ["count": 1],
            body: .empty(),
            scripts: ["double": "() => { state.set('count', state.get('count') * 2) }"]))
        let scope = StateScope(store: store)

        try scope.performThrowing([.set(path: "count", to: 5), .call(name: "double", args: []),
                                   .set(path: "label", to: .operation(.concat, ["=", .var("count")]))])
        XCTAssertEqual(store.root, ["count": 10, "label": "=10"])
    }

    func testScriptFailureRollsBackTheWholeActionList() throws {
        let store = StateStore(payload: InjectedPayload(
            state: ["count": 1], body: .empty(),
            scripts: ["fail": "() => { state.set('count', 99); throw new Error('bad input') }"]))
        XCTAssertThrowsError(try StateScope(store: store).performThrowing([.set(path: "count", to: 2), .call(name: "fail", args: [])]))
        XCTAssertEqual(store.root, ["count": 1])
    }

    func testPayloadWithBrokenScriptReportsItAndKeepsTheRest() {
        var errors: [EvaluationError] = []
        let previous = StateStore.defaultOnError
        StateStore.defaultOnError = { errors.append($0 as! EvaluationError) }
        defer { StateStore.defaultOnError = previous }

        let store = StateStore(payload: InjectedPayload(body: .empty(), scripts: ["bad": "nope(", "good": "() => 1"]))
        XCTAssertEqual(errors.count, 1)
        XCTAssertNotNil(store.functions["good"])
        XCTAssertNil(store.functions["bad"])
    }

    // MARK: expressions

    func testExpressionCallsAreEvaluatedAndRendered() throws {
        let payload = try JSONDecoder().decode(InjectedPayload.self, from: Data(#"""
        {"state": {"price": 4.5},
         "scripts": {"formatPrice": "(amount, currency) => (currency === 'USD' ? '$' : '') + amount.toFixed(2)"},
         "body": {"text": {"value": {"call": ["formatPrice", {"var": "price"}, "USD"]}}}}
        """#.utf8))
        let store = StateStore(payload: payload)
        let screen = InjectedScreen(store: store, payload: payload)
        XCTAssertEqual(try screen.inspect().find(ViewType.Text.self).string(), "$4.50")
    }

    func testExpressionCallsCannotWriteState() throws {
        let store = StateStore(payload: InjectedPayload(state: ["n": 1], body: .empty(),
                                                        scripts: ["sneaky": "() => { state.set('n', 2); return 'x' }"]))
        var errors: [EvaluationError] = []
        store.onError = { errors.append($0 as! EvaluationError) }
        XCTAssertNil(StateScope(store: store).evaluate(.operation(.call, ["sneaky"])))
        XCTAssertEqual(store.root, ["n": 1])
        guard case .readOnly? = errors.first else { return XCTFail("\(errors)") }
    }

    func testUnknownFunctionInExpression() {
        let scope = StateScope(store: StateStore())
        XCTAssertThrowsError(try ExpressionEvaluator().evaluate(.operation(.call, ["missing", 1]), in: scope)) {
            XCTAssertEqual($0 as? EvaluationError, .unknownFunction("missing"))
        }
        // Plain value scopes have no functions.
        XCTAssertThrowsError(try ExpressionEvaluator().evaluate(.operation(.call, ["x"]), in: RuntimeValue.object([:])))
    }

    func testButtonCallsScriptEndToEnd() throws {
        let payload = try JSONDecoder().decode(InjectedPayload.self, from: Data(#"""
        {"state": {"todos": []},
         "scripts": {"addTodo": "(title) => { state.set('todos', state.get('todos').concat([{ title }])) }"},
         "body": {"vStack": {"children": [
           {"button": {"title": "Add", "action": [{"call": "addTodo", "args": ["Milk"]}]}},
           {"text": {"value": {"format": ["{0} to-dos", {"count": {"var": "todos"}}]}}}
         ]}}}
        """#.utf8))
        let store = StateStore(payload: payload)
        let screen = InjectedScreen(store: store, payload: payload)
        try screen.inspect().find(button: "Add").tap()
        try screen.inspect().find(button: "Add").tap()
        XCTAssertEqual(try screen.inspect().find(text: "2 to-dos").string(), "2 to-dos")
        XCTAssertEqual(store.root, ["todos": [["title": "Milk"], ["title": "Milk"]]])
    }
}
