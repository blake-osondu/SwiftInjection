//
//  InjectedState+Expression.swift
//  SwiftInjection
//

import Foundation

/// Lets expressions read the existing parameter-slot state. A path's first segment is a value id,
/// e.g. `{"var": "count"}` or `{"var": "user.name"}` for a nested state.
extension InjectedState: ExpressionScope {
    public func value(at path: [String]) -> RuntimeValue? {
        runtimeValue.value(at: path)
    }

    public var runtimeValue: RuntimeValue {
        var fields: [String: RuntimeValue] = [:]
        for parameter in allParameters() where parameter != .none {
            fields[parameter.id] = parameter.runtimeValue
        }
        return .object(fields)
    }
}

extension InjectedValue {
    public var runtimeValue: RuntimeValue {
        switch self {
        case .none: return .null
        case .string(_, _, let value): return .string(value)
        case .integer(_, _, let value): return .number(Double(value))
        case .double(_, _, let value): return .number(value)
        case .boolean(_, _, let value): return .bool(value)
        case .data(_, _, let value): return .string(value.base64EncodedString())
        case .date(_, _, let value): return .string(ISO8601DateFormatter().string(from: value))
        case .state(_, _, let value): return value.runtimeValue
        case .stateCollection(_, _, let value): return .object(value.mapValues(\.runtimeValue))
        case .stringArray(_, _, let value): return .array(value.map { .string($0) })
        case .integerArray(_, _, let value): return .array(value.map { .number(Double($0)) })
        case .doubleArray(_, _, let value): return .array(value.map { .number($0) })
        case .booleanArray(_, _, let value): return .array(value.map { .bool($0) })
        case .dataArray(_, _, let value): return .array(value.map { .string($0.base64EncodedString()) })
        case .dateArray(_, _, let value):
            let formatter = ISO8601DateFormatter()
            return .array(value.map { .string(formatter.string(from: $0)) })
        case .stateArray(_, _, let value): return .array(value.map(\.runtimeValue))
        }
    }
}
