//
//  RuntimeConvertible.swift
//  SwiftInjection
//

import Foundation
import CoreGraphics

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
