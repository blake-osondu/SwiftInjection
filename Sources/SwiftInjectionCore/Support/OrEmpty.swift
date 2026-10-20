//
//  OrEmpty.swift
//  SwiftInjection
//

import Foundation

/// Types with a natural empty value used when a key is missing from the payload.
public protocol EmptyDefaultable {
    static var emptyValue: Self { get }
    var isEmptyValue: Bool { get }
}

extension Array: EmptyDefaultable {
    public static var emptyValue: Array { [] }
    public var isEmptyValue: Bool { isEmpty }
}

extension String: EmptyDefaultable {
    public static var emptyValue: String { "" }
    public var isEmptyValue: Bool { isEmpty }
}

extension RuntimeValue: EmptyDefaultable {
    public static var emptyValue: RuntimeValue { [:] }
    public var isEmptyValue: Bool { self == [:] }
}

extension Dictionary: EmptyDefaultable {
    public static var emptyValue: Dictionary { [:] }
    public var isEmptyValue: Bool { isEmpty }
}

/// Decodes a missing key as the empty value, and leaves empty values out when encoding, so payloads can omit
/// `id`, `modifiers`, `children`, … (synthesized Codable otherwise requires and writes every key).
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

extension KeyedEncodingContainer {
    public mutating func encode<Value>(_ value: OrEmpty<Value>, forKey key: Key) throws {
        guard !value.wrappedValue.isEmptyValue else { return }
        try encode(value.wrappedValue, forKey: key)
    }
}
