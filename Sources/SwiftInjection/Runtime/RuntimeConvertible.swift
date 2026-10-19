//
//  RuntimeConvertible.swift
//  SwiftInjection
//

import Foundation
import CoreGraphics
import SwiftUI

/// A Swift type an evaluated expression can be converted to.
public protocol RuntimeConvertible {
    init?(runtimeValue: RuntimeValue)
    static var runtimeTypeName: String { get }
}

extension Double: RuntimeConvertible {
    public init?(runtimeValue: RuntimeValue) {
        guard case .number(let value) = runtimeValue else { return nil }
        self = value
    }
    public static var runtimeTypeName: String { "number" }
}

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

extension Int: RuntimeConvertible {
    public init?(runtimeValue: RuntimeValue) {
        guard case .number(let value) = runtimeValue, let int = Int(exactly: value) else { return nil }
        self = int
    }
    public static var runtimeTypeName: String { "integer" }
}

extension Bool: RuntimeConvertible {
    public init?(runtimeValue: RuntimeValue) {
        guard case .bool(let value) = runtimeValue else { return nil }
        self = value
    }
    public static var runtimeTypeName: String { "bool" }
}

extension String: RuntimeConvertible {
    public init?(runtimeValue: RuntimeValue) {
        guard case .string(let value) = runtimeValue else { return nil }
        self = value
    }
    public static var runtimeTypeName: String { "string" }
}

/// String-backed option enums (`InjectedEdgeSet`, `InjectedFontWeight`, …) resolve from their raw value.
extension RuntimeConvertible where Self: RawRepresentable, RawValue == String {
    public init?(runtimeValue: RuntimeValue) {
        guard case .string(let raw) = runtimeValue else { return nil }
        self.init(rawValue: raw)
    }
    public static var runtimeTypeName: String { "\(Self.self)" }
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

extension Date: RuntimeConvertible {
    /// ISO 8601 strings (with or without fractional seconds), or numbers as seconds since 1970.
    public init?(runtimeValue: RuntimeValue) {
        switch runtimeValue {
        case .number(let seconds):
            self = Date(timeIntervalSince1970: seconds)
        case .string(let string):
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: string) {
                self = date
                return
            }
            formatter.formatOptions.insert(.withFractionalSeconds)
            guard let date = formatter.date(from: string) else { return nil }
            self = date
        default:
            return nil
        }
    }
    public static var runtimeTypeName: String { "date" }

    var runtimeValue: RuntimeValue {
        .string(ISO8601DateFormatter().string(from: self))
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
