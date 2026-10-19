//
//  RuntimeValue.swift
//  SwiftInjection
//

import Foundation

/// A JSON-shaped dynamic value that expressions, actions and scripts operate on.
public enum RuntimeValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([RuntimeValue])
    case object([String: RuntimeValue])

    public var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "bool"
        case .number: return "number"
        case .string: return "string"
        case .array: return "array"
        case .object: return "object"
        }
    }

    /// Text used when a value is interpolated into a string. Integral numbers drop the trailing ".0".
    public var displayString: String {
        switch self {
        case .null: return ""
        case .bool(let value): return value ? "true" : "false"
        case .number(let value):
            if value.rounded() == value, abs(value) < 1e15 {
                return String(Int64(value))
            }
            return String(value)
        case .string(let value): return value
        case .array(let values): return "[" + values.map(\.displayString).joined(separator: ", ") + "]"
        case .object: return "[object]"
        }
    }

    /// Looks up a dotted path such as `user.addresses.0.city`. Array segments are integer indices.
    public func value(at path: [String]) -> RuntimeValue? {
        guard let head = path.first else { return self }
        let rest = Array(path.dropFirst())
        switch self {
        case .object(let dictionary):
            return dictionary[head]?.value(at: rest)
        case .array(let values):
            guard let index = Int(head), values.indices.contains(index) else { return nil }
            return values[index].value(at: rest)
        default:
            return nil
        }
    }

    /// Returns a copy with the value at `path` replaced, creating intermediate objects as needed.
    public func setting(_ newValue: RuntimeValue, at path: [String]) -> RuntimeValue {
        guard let head = path.first else { return newValue }
        let rest = Array(path.dropFirst())
        switch self {
        case .array(var values):
            if let index = Int(head), values.indices.contains(index) {
                values[index] = values[index].setting(newValue, at: rest)
                return .array(values)
            }
            return self
        case .object(var dictionary):
            dictionary[head] = (dictionary[head] ?? .null).setting(newValue, at: rest)
            return .object(dictionary)
        default:
            return .object([head: RuntimeValue.null.setting(newValue, at: rest)])
        }
    }
}

extension RuntimeValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([RuntimeValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: RuntimeValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension RuntimeValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
                        ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
                        ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: RuntimeValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, RuntimeValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
