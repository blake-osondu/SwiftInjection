import XCTest
@testable import SwiftInjection

final class ExpressionTests: XCTestCase {

    let scope: RuntimeValue = [
        "count": 3,
        "price": 2.5,
        "name": "Ada",
        "isMember": true,
        "tags": ["a", "b", "c"],
        "user": ["address": ["city": "Lagos"]],
    ]

    private func eval(_ json: String, file: StaticString = #filePath, line: UInt = #line) throws -> RuntimeValue {
        let expression = try JSONDecoder().decode(InjectedExpression.self, from: Data(json.utf8))
        return try ExpressionEvaluator().evaluate(expression, in: scope)
    }

    private func assertError(_ json: String, _ expected: EvaluationError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try eval(json), file: file, line: line) { error in
            XCTAssertEqual(error as? EvaluationError, expected, file: file, line: line)
        }
    }

    // MARK: literals & variables

    func testLiterals() throws {
        XCTAssertEqual(try eval("1"), 1)
        XCTAssertEqual(try eval("\"hi\""), "hi")
        XCTAssertEqual(try eval("true"), true)
        XCTAssertEqual(try eval("null"), nil)
        XCTAssertEqual(try eval("[1, {\"var\": \"count\"}]"), [1, 3])
        XCTAssertEqual(try eval(#"{"object": {"n": {"var": "name"}}}"#), ["n": "Ada"])
    }

    func testVariables() throws {
        XCTAssertEqual(try eval(#"{"var": "count"}"#), 3)
        XCTAssertEqual(try eval(#"{"var": "user.address.city"}"#), "Lagos")
        XCTAssertEqual(try eval(#"{"var": "tags.1"}"#), "b")
        XCTAssertEqual(try eval(#"{"var": ["missing", 0]}"#), 0)
        assertError(#"{"var": "missing"}"#, .unknownVariable("missing"))
    }

    // MARK: arithmetic

    func testArithmetic() throws {
        XCTAssertEqual(try eval(#"{"add": [{"var": "count"}, 1, 2]}"#), 6)
        XCTAssertEqual(try eval(#"{"sub": [10, 4]}"#), 6)
        XCTAssertEqual(try eval(#"{"sub": 4}"#), -4)
        XCTAssertEqual(try eval(#"{"mul": [{"var": "price"}, 2]}"#), 5)
        XCTAssertEqual(try eval(#"{"div": [7, 2]}"#), 3.5)
        XCTAssertEqual(try eval(#"{"mod": [7, 2]}"#), 1)
        assertError(#"{"div": [1, 0]}"#, .divisionByZero)
        assertError(#"{"add": [1, "2"]}"#, .typeMismatch(op: "add", expected: "number", got: "string"))
        assertError(#"{"div": [1]}"#, .arity(op: "div", expected: "2", got: 1))
    }

    // MARK: comparison & logic

    func testComparison() throws {
        XCTAssertEqual(try eval(#"{"eq": [{"var": "count"}, 3]}"#), true)
        XCTAssertEqual(try eval(#"{"neq": [{"var": "name"}, "Bob"]}"#), true)
        XCTAssertEqual(try eval(#"{"eq": [1, "1"]}"#), false)
        XCTAssertEqual(try eval(#"{"gt": [{"var": "count"}, 2]}"#), true)
        XCTAssertEqual(try eval(#"{"gte": [3, 3]}"#), true)
        XCTAssertEqual(try eval(#"{"lt": ["a", "b"]}"#), true)
        XCTAssertEqual(try eval(#"{"lte": [4, 3]}"#), false)
        assertError(#"{"gt": [1, "a"]}"#, .typeMismatch(op: "gt", expected: "two numbers or two strings", got: "number, string"))
    }

    func testLogic() throws {
        XCTAssertEqual(try eval(#"{"and": [true, {"var": "isMember"}]}"#), true)
        XCTAssertEqual(try eval(#"{"or": [false, false]}"#), false)
        XCTAssertEqual(try eval(#"{"not": {"var": "isMember"}}"#), false)
        XCTAssertEqual(try eval(#"{"if": [{"gt": [{"var": "count"}, 10]}, "big", "small"]}"#), "small")
        assertError(#"{"and": [1, true]}"#, .typeMismatch(op: "and", expected: "bool", got: "number"))
    }

    func testLogicShortCircuits() throws {
        // The right-hand side would throw if evaluated.
        XCTAssertEqual(try eval(#"{"and": [false, {"var": "missing"}]}"#), false)
        XCTAssertEqual(try eval(#"{"or": [true, {"var": "missing"}]}"#), true)
        XCTAssertEqual(try eval(#"{"if": [true, 1, {"var": "missing"}]}"#), 1)
    }

    // MARK: strings & collections

    func testStrings() throws {
        XCTAssertEqual(try eval(#"{"concat": ["Count: ", {"var": "count"}]}"#), "Count: 3")
        XCTAssertEqual(try eval(#"{"format": ["{0} has {1} tags", {"var": "name"}, {"count": {"var": "tags"}}]}"#), "Ada has 3 tags")
        XCTAssertEqual(try eval(#"{"length": {"var": "name"}}"#), 3)
    }

    func testCollections() throws {
        XCTAssertEqual(try eval(#"{"count": {"var": "tags"}}"#), 3)
        XCTAssertEqual(try eval(#"{"at": [{"var": "tags"}, 2]}"#), "c")
        XCTAssertEqual(try eval(#"{"at": [{"var": "user.address"}, "city"]}"#), "Lagos")
        assertError(#"{"at": [{"var": "tags"}, 9]}"#, .indexOutOfRange(9))
    }

    // MARK: decoding & safety

    func testDecodingRejectsUnknownOperatorsAndMultiKeyObjects() {
        XCTAssertThrowsError(try eval(#"{"explode": [1]}"#))
        XCTAssertThrowsError(try eval(#"{"add": [1], "sub": [2]}"#))
    }

    func testDepthLimit() throws {
        var expression: InjectedExpression = 1
        for _ in 0..<200 { expression = .operation(.add, [expression]) }
        XCTAssertThrowsError(try ExpressionEvaluator().evaluate(expression, in: scope)) { error in
            XCTAssertEqual(error as? EvaluationError, .tooDeep(limit: 128))
        }
    }

    func testRoundTripEncoding() throws {
        let json = #"{"if":[{"and":[{"gt":[{"var":"count"},1]},{"var":["isMember",false]}]},{"object":{"k":[1,"x"]}},{"concat":["a",{"var":"name"}]}]}"#
        let decoded = try JSONDecoder().decode(InjectedExpression.self, from: Data(json.utf8))
        let reencoded = try JSONDecoder().decode(InjectedExpression.self, from: JSONEncoder().encode(decoded))
        XCTAssertEqual(decoded, reencoded)

        let objectLiteral = InjectedExpression.literal(["a": 1])
        let decodedLiteral = try JSONDecoder().decode(InjectedExpression.self, from: JSONEncoder().encode(objectLiteral))
        XCTAssertEqual(try ExpressionEvaluator().evaluate(decodedLiteral, in: scope), ["a": 1])
    }

    // MARK: integration with existing state

    func testEvaluatesAgainstInjectedState() throws {
        let state = InjectedState(
            id: "screen",
            parameter1: .integer(stateId: "screen", id: "count", value: 11),
            parameter2: .state(stateId: "screen", id: "user", value: InjectedState(
                id: "user", parameter1: .string(stateId: "user", id: "name", value: "Ada"))))
        let expression: InjectedExpression = .operation(.and, [
            .operation(.gt, [.var("count"), 10]),
            .operation(.eq, [.var("user.name"), "Ada"]),
        ])
        XCTAssertTrue(try ExpressionEvaluator().condition(expression, in: state))
    }
}
