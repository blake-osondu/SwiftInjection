//
//  RuntimeConvertible.swift
//  SwiftInjectionCore
//

import Foundation

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

    public var runtimeValue: RuntimeValue {
        .string(ISO8601DateFormatter().string(from: self))
    }
}
