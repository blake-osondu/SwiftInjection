import XCTest
import Combine
@testable import SwiftInjection

final class StateRuntimeTests: XCTestCase {

    private func makeScope(_ root: RuntimeValue) -> StateScope {
        StateScope(store: StateStore(root))
    }

    private func actions(_ json: String) throws -> [InjectedAction] {
        try JSONDecoder().decode([InjectedAction].self, from: Data(json.utf8))
    }

    // MARK: decoding

    func testDecodesEveryActionForm() throws {
        let decoded = try actions(#"""
        [
          {"set": "count", "to": {"add": [{"var": "count"}, 1]}},
          {"if": {"gt": [{"var": "count"}, 1]}, "then": [{"set": "big", "to": true}], "else": []},
          {"delay": 0.5, "do": [{"set": "done", "to": true}]},
          {"call": "track", "args": ["tap"]}
        ]
        """#)
        XCTAssertEqual(decoded, [
            .set(path: "count", to: .operation(.add, [.var("count"), 1])),
            .if(.operation(.gt, [.var("count"), 1]), then: [.set(path: "big", to: true)], else: []),
            .delay(seconds: 0.5, do: [.set(path: "done", to: true)]),
            .call(name: "track", args: ["tap"]),
        ])
        let roundTripped = try JSONDecoder().decode([InjectedAction].self, from: JSONEncoder().encode(decoded))
        XCTAssertEqual(roundTripped, decoded)
    }

    func testDecodingRejectsAmbiguousUnknownAndMisspelledActions() {
        XCTAssertThrowsError(try actions(#"[{"set": "a", "to": 1, "call": "f"}]"#))
        XCTAssertThrowsError(try actions(#"[{"navigate": "home"}]"#))
        XCTAssertThrowsError(try actions(#"[{"set": "a", "too": 1}]"#))
    }

    // MARK: running actions

    func testSetActionsRunSequentially() throws {
        let scope = makeScope(["count": 0])
        try scope.performThrowing(actions(#"""
        [ {"set": "count", "to": {"add": [{"var": "count"}, 1]}},
          {"set": "count", "to": {"mul": [{"var": "count"}, 10]}},
          {"set": "label", "to": {"format": ["Count: {0}", {"var": "count"}]}} ]
        """#))
        XCTAssertEqual(scope.store.root, ["count": 10, "label": "Count: 10"])
    }

    func testSetCreatesNestedPaths() throws {
        let scope = makeScope([:])
        try scope.performThrowing([.set(path: "form.email", to: "a@b.co")])
        XCTAssertEqual(scope.store.root, ["form": ["email": "a@b.co"]])
    }

    func testIfElse() throws {
        let scope = makeScope(["count": 3])
        let toggle: [InjectedAction] = [
            .if(.operation(.gte, [.var("count"), 5]),
                then: [.set(path: "size", to: "big")],
                else: [.set(path: "size", to: "small")]),
        ]
        try scope.performThrowing(toggle)
        XCTAssertEqual(scope.value(at: ["size"]), "small")
        try scope.performThrowing([.set(path: "count", to: 7)] + toggle)
        XCTAssertEqual(scope.value(at: ["size"]), "big")
    }

    func testFailedActionListAppliesNothing() {
        let scope = makeScope(["count": 1])
        XCTAssertThrowsError(try scope.performThrowing([
            .set(path: "count", to: 2),
            .delay(seconds: 0, do: [.set(path: "late", to: true)]),
            .set(path: "count", to: .operation(.div, [1, 0])),
        ])) { XCTAssertEqual($0 as? EvaluationError, .divisionByZero) }
        XCTAssertEqual(scope.store.root, ["count": 1])

        // The delay block was never scheduled either.
        let settled = expectation(description: "main queue drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertNil(scope.value(at: ["late"]))
    }

    func testPerformReportsErrorsToStore() {
        let scope = makeScope([:])
        var reported: [EvaluationError] = []
        scope.store.onError = { reported.append($0 as! EvaluationError) }
        scope.perform([.set(path: "x", to: .var("missing"))])
        XCTAssertEqual(reported, [.unknownVariable("missing")])
    }

    func testPublishesOncePerActionList() throws {
        let scope = makeScope(["count": 0])
        var publishes = 0
        let cancellable = scope.store.objectWillChange.sink { publishes += 1 }
        try scope.performThrowing([.set(path: "count", to: 1), .set(path: "count", to: 2), .set(path: "count", to: 3)])
        XCTAssertEqual(publishes, 1)
        try scope.performThrowing([.set(path: "count", to: 3)])  // no change, no publish
        XCTAssertEqual(publishes, 1)
        cancellable.cancel()
    }

    func testDelayRunsLater() throws {
        let scope = makeScope(["phase": "start"])
        try scope.performThrowing([.delay(seconds: 0.05, do: [.set(path: "phase", to: "end")])])
        XCTAssertEqual(scope.value(at: ["phase"]), "start")

        let ran = expectation(description: "delay ran")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ran.fulfill() }
        wait(for: [ran], timeout: 1)
        XCTAssertEqual(scope.value(at: ["phase"]), "end")
    }

    func testCallInvokesHostFunctionWhichCanMutateState() throws {
        let scope = makeScope(["log": []])
        scope.store.functions["track"] = { args, state in
            guard case .array(let existing)? = state.value(at: ["log"]) else { return .null }
            state = state.setting(.array(existing + args), at: ["log"])
            return .null
        }
        try scope.performThrowing([.call(name: "track", args: [.concat("tap", .var("missing", default: "!"))])])
        XCTAssertEqual(scope.store.root, ["log": ["tap!"]])

        XCTAssertThrowsError(try scope.performThrowing([.call(name: "nope", args: [])])) {
            XCTAssertEqual($0 as? EvaluationError, .unknownFunction("nope"))
        }
    }

    // MARK: scopes & locals

    func testChildScopeAliasesLoopItem() throws {
        let root = makeScope(["todos": [["title": "Milk", "done": false], ["title": "Eggs", "done": false]]])
        let item = root.child("item", at: "todos.1").child("index", value: 1)

        XCTAssertEqual(item.string(.var("item.title")), "Eggs")
        XCTAssertEqual(item.number(.var("index")), 1)

        try item.performThrowing([.set(path: "item.done", to: true)])
        XCTAssertEqual(root.value(at: ["todos", "1", "done"]), true)
        XCTAssertEqual(root.value(at: ["todos", "0", "done"]), false)

        XCTAssertThrowsError(try item.performThrowing([.set(path: "index", to: 5)])) {
            XCTAssertEqual($0 as? EvaluationError, .readOnly("index"))
        }
    }

    func testNestedChildScopesResolveThroughParents() throws {
        let root = makeScope(["groups": [["items": [["name": "a"], ["name": "b"]]]]])
        let group = root.child("group", at: "groups.0")
        let item = group.child("item", at: "group.items.1")
        try item.performThrowing([.set(path: "item.name", to: "B")])
        XCTAssertEqual(root.value(at: ["groups", "0", "items", "1", "name"]), "B")
    }

    func testBindingsWriteThroughLocals() {
        let root = makeScope(["todos": [["title": "Milk", "done": false]]])
        let item = root.child("item", at: "todos.0")

        let title = item.stringBinding("item.title")
        XCTAssertEqual(title.wrappedValue, "Milk")
        title.wrappedValue = "Oat milk"
        XCTAssertEqual(root.value(at: ["todos", "0", "title"]), "Oat milk")

        let done = item.boolBinding("item.done")
        done.wrappedValue = true
        XCTAssertEqual(root.value(at: ["todos", "0", "done"]), true)
    }

    func testDisplayHelpersFallBackOnErrors() {
        let scope = makeScope(["n": 2])
        scope.store.onError = { _ in }
        XCTAssertEqual(scope.string(.var("missing"), default: "—"), "—")
        XCTAssertEqual(scope.string(.var("n")), "2")
        XCTAssertFalse(scope.bool(.var("n")))  // wrong type → fallback
        XCTAssertEqual(scope.number(nil, default: 4), 4)
    }
}

private extension InjectedExpression {
    static func concat(_ args: InjectedExpression...) -> InjectedExpression { .operation(.concat, args) }
}
