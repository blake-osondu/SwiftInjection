//
//  OrEmpty.swift
//  SwiftInjection
//

import Foundation

/// Types with a natural empty value used when a key is missing from the payload.
public protocol EmptyDefaultable {
    static var emptyValue: Self { get }
}

extension Array: EmptyDefaultable {
    public static var emptyValue: Array { [] }
}

extension String: EmptyDefaultable {
    public static var emptyValue: String { "" }
}

extension RuntimeValue: EmptyDefaultable {
    public static var emptyValue: RuntimeValue { [:] }
}

extension Dictionary: EmptyDefaultable {
    public static var emptyValue: Dictionary { [:] }
}

/// Decodes a missing key as the empty value, so payloads can omit `id`, `modifiers`, `children`, …
/// (synthesized Codable otherwise requires every non-optional key).
@propertyWrapper
public struct OrEmpty<Value: Codable & EmptyDefaultable>: Codable {
    public var wrappedValue: Value

    public init(wrappedValue: Value = .emptyValue) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        wrappedValue = try Value(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    public func decode<Value>(_ type: OrEmpty<Value>.Type, forKey key: Key) throws -> OrEmpty<Value> {
        try decodeIfPresent(type, forKey: key) ?? OrEmpty()
    }
}
