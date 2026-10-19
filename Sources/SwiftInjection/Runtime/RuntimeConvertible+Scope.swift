//
//  RuntimeConvertible+Scope.swift
//  SwiftInjection
//

import Foundation
import CoreGraphics
import SwiftUI
import SwiftInjectionCore

extension CGFloat: RuntimeConvertible {
    /// Numbers, or the string `"infinity"` (for `maxWidth` and friends).
    public init?(runtimeValue: RuntimeValue) {
        switch runtimeValue {
        case .number(let value): self = CGFloat(value)
        case .string("infinity"): self = .infinity
        default: return nil
        }
    }
    public static var runtimeTypeName: String { "number" }
}

extension StateScope {
    /// Evaluates an optional expression and converts it. Returns nil when the expression is absent;
    /// evaluation failures and type mismatches are reported to the store and also return nil.
    public func resolve<T: RuntimeConvertible>(_ expression: InjectedExpression?, as type: T.Type = T.self) -> T? {
        guard let expression, let value = evaluate(expression) else { return nil }
        guard let converted = T(runtimeValue: value) else {
            store.report(EvaluationError.typeMismatch(op: "resolve", expected: T.runtimeTypeName, got: value.displayString))
            return nil
        }
        return converted
    }
}

extension StateScope {
    /// Reads and writes an ISO 8601 date at `path`. A missing or invalid value reads as now.
    public func dateBinding(_ path: String) -> Binding<Date> {
        let binding = binding(path)
        return Binding(
            get: { Date(runtimeValue: binding.wrappedValue) ?? Date() },
            set: { binding.wrappedValue = $0.runtimeValue })
    }

    /// The array at `path`, or empty (reported) if it isn't one.
    func items(at path: String) -> [RuntimeValue] {
        switch value(at: path.statePath) {
        case .array(let items)?:
            return items
        case nil, .null?:
            return []
        case let other?:
            store.report(EvaluationError.typeMismatch(op: "items", expected: "array", got: other.typeName))
            return []
        }
    }

    /// A scope for the element at `index` of the array at `path`: `name` aliases the element and
    /// `index` holds its position.
    func itemScope(_ path: String, index: Int, name: String, indexName: String = "index") -> StateScope {
        child(name, at: "\(path).\(index)").child(indexName, value: .number(Double(index)))
    }
}
