import XCTest
import Combine
@testable import SwiftInjection

final class StateEqualityTests: XCTestCase {

    func testValuesWithSameIdButDifferentValuesAreNotEqual() {
        let a = InjectedValue.integer(stateId: "screen", id: "count", value: 1)
        let b = InjectedValue.integer(stateId: "screen", id: "count", value: 2)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, .integer(stateId: "screen", id: "count", value: 1))
    }

    func testStatesWithChangedValueAreNotEqual() {
        let before = InjectedState(id: "screen", parameter1: .integer(stateId: "screen", id: "count", value: 1))
        let after = updateState(state: before, newValue: .integer(stateId: "screen", id: "count", value: 2))
        XCTAssertNotEqual(before, after)
        XCTAssertEqual(after.map(key: "count")?.integer, 2)
    }

    func testValueChangePropagatesThroughRemoveDuplicates() {
        let signal = StateSignal(InjectedState(id: "screen", parameter1: .integer(stateId: "screen", id: "count", value: 1)))
        var received: [Int?] = []
        let cancellable = signal
            .removeDuplicates()
            .sink { received.append($0.map(key: "count")?.integer) }

        signal.value = updateState(state: signal.value, newValue: .integer(stateId: "screen", id: "count", value: 2))
        signal.value = updateState(state: signal.value, newValue: .integer(stateId: "screen", id: "count", value: 2))

        XCTAssertEqual(received, [1, 2])
        cancellable.cancel()
    }

    func testUpdateStateFillsFirstEmptyParameterForNewKey() {
        let state = InjectedState(id: "screen", parameter1: .integer(stateId: "screen", id: "count", value: 1))
        let updated = updateState(state: state, newValue: .string(stateId: "screen", id: "title", value: "Hi"))
        XCTAssertEqual(updated.parameter2, .string(stateId: "screen", id: "title", value: "Hi"))
        XCTAssertEqual(updated.parameter1.integer, 1)
    }
}
