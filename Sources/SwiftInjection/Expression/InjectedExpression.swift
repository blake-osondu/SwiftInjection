//
//  InjectedExpression.swift
//  SwiftInjection
//

import Foundation

/// A pure expression stored as JSON and evaluated on device.
///
/// JSON form: scalars are literals, arrays are arrays of expressions, and an operator is an
/// object with exactly one key, e.g. `{"add": [{"var": "count"}, 1]}`.
/// Object literals use `{"object": {"key": <expr>}}`.
public indirect enum InjectedExpression: Hashable, Sendable {
    case literal(RuntimeValue)
    case array([InjectedExpression])
    case object([String: InjectedExpression])
    /// `{"var": "path"}` or `{"var": ["path", <default>]}`
    case variable(path: String, fallback: InjectedExpression?)
    case operation(Operator, [InjectedExpression])

    public enum Operator: String, CaseIterable, Sendable {
        // arithmetic
        case add, sub, mul, div, mod
        // comparison
        case eq, neq, gt, gte, lt, lte
        // logic
        case and, or, not
        case `if`
        // strings
        case concat, format, length
        // collections
        case count, at
    }
}

// MARK: - Codable

extension InjectedExpression: Codable {
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: Key.self) {
            let keys = container.allKeys
            guard keys.count == 1, let key = keys.first else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "An expression object must have exactly one key (got \(keys.map(\.stringValue).sorted())). Use {\"object\": {...}} for object literals."))
            }
            switch key.stringValue {
            case "var":
                if let path = try? container.decode(String.self, forKey: key) {
                    self = .variable(path: path, fallback: nil)
                } else {
                    var args = try container.nestedUnkeyedContainer(forKey: key)
                    let path = try args.decode(String.self)
                    let fallback = args.isAtEnd ? nil : try args.decode(InjectedExpression.self)
                    self = .variable(path: path, fallback: fallback)
                }
            case "object":
                self = .object(try container.decode([String: InjectedExpression].self, forKey: key))
            default:
                guard let op = Operator(rawValue: key.stringValue) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: key, in: container,
                        debugDescription: "Unknown operator '\(key.stringValue)'")
                }
                // Operands may be an array or, for unary use, a single expression.
                if let args = try? container.decode([InjectedExpression].self, forKey: key) {
                    self = .operation(op, args)
                } else {
                    self = .operation(op, [try container.decode(InjectedExpression.self, forKey: key)])
                }
            }
            return
        }
        if let elements = try? [InjectedExpression](from: decoder) {
            self = .array(elements)
            return
        }
        self = .literal(try RuntimeValue(from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(.object(let fields)):
            // A bare JSON object would decode as an operator, so object literals are wrapped.
            try InjectedExpression.object(fields.mapValues { .literal($0) }).encode(to: encoder)
        case .literal(let value):
            try value.encode(to: encoder)
        case .array(let elements):
            try elements.encode(to: encoder)
        case .object(let fields):
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(fields, forKey: Key(stringValue: "object"))
        case .variable(let path, let fallback):
            var container = encoder.container(keyedBy: Key.self)
            if let fallback {
                var args = container.nestedUnkeyedContainer(forKey: Key(stringValue: "var"))
                try args.encode(path)
                try args.encode(fallback)
            } else {
                try container.encode(path, forKey: Key(stringValue: "var"))
            }
        case .operation(let op, let args):
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(args, forKey: Key(stringValue: op.rawValue))
        }
    }
}

// MARK: - Literals

extension InjectedExpression: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
                              ExpressibleByFloatLiteral, ExpressibleByStringLiteral {
    public init(booleanLiteral value: Bool) { self = .literal(.bool(value)) }
    public init(integerLiteral value: Int) { self = .literal(.number(Double(value))) }
    public init(floatLiteral value: Double) { self = .literal(.number(value)) }
    public init(stringLiteral value: String) { self = .literal(.string(value)) }
}

extension InjectedExpression {
    public static func `var`(_ path: String, default fallback: InjectedExpression? = nil) -> InjectedExpression {
        .variable(path: path, fallback: fallback)
    }
}
