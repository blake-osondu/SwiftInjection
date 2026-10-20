//
//  RuntimeValue+Codable.swift
//  SwiftInjectionCore
//

import Foundation

extension RuntimeValue {
    /// Converts any `Encodable` model (e.g. app state from TCA or a view model) into payload state.
    /// Dates become ISO 8601 strings, which date pickers and `Date(runtimeValue:)` read.
    public init<Value: Encodable>(encoding value: Value) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self = try JSONDecoder().decode(RuntimeValue.self, from: encoder.encode(value))
    }

    /// Decodes payload state back into a model.
    public func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: JSONEncoder().encode(self))
    }
}
