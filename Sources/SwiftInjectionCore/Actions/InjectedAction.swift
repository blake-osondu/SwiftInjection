//
//  InjectedAction.swift
//  SwiftInjection
//

import Foundation

/// A side effect run in response to an event, e.g. a button tap.
///
/// JSON forms:
/// - `{"set": "path", "to": <expr>}`
/// - `{"if": <expr>, "then": [actions], "else": [actions]}`
/// - `{"delay": seconds, "do": [actions]}`
/// - `{"call": "name", "args": [<expr>]}`
public indirect enum InjectedAction: Hashable, Sendable {
    case set(path: String, to: InjectedExpression)
    case `if`(InjectedExpression, then: [InjectedAction], else: [InjectedAction])
    case delay(seconds: Double, do: [InjectedAction])
    case call(name: String, args: [InjectedExpression])
}

extension InjectedAction: Codable {
    private struct Key: CodingKey, Hashable {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ stringValue: String) { self.stringValue = stringValue }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// The key that identifies each action, and every key that action accepts.
    private static let shapes: [String: Set<String>] = [
        "set": ["set", "to"],
        "if": ["if", "then", "else"],
        "delay": ["delay", "do"],
        "call": ["call", "args"],
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let keys = Set(container.allKeys.map(\.stringValue))
        let kinds = keys.intersection(Self.shapes.keys)
        guard kinds.count == 1, let kind = kinds.first, let allowed = Self.shapes[kind] else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "An action needs exactly one of \(Self.shapes.keys.sorted()) (got \(keys.sorted()))"))
        }
        let unexpected = keys.subtracting(allowed)
        guard unexpected.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unexpected key(s) \(unexpected.sorted()) for '\(kind)' action"))
        }

        switch kind {
        case "set":
            self = .set(path: try container.decode(String.self, forKey: Key("set")),
                        to: try container.decode(InjectedExpression.self, forKey: Key("to")))
        case "if":
            self = .if(try container.decode(InjectedExpression.self, forKey: Key("if")),
                       then: try container.decodeIfPresent([InjectedAction].self, forKey: Key("then")) ?? [],
                       else: try container.decodeIfPresent([InjectedAction].self, forKey: Key("else")) ?? [])
        case "delay":
            self = .delay(seconds: try container.decode(Double.self, forKey: Key("delay")),
                          do: try container.decode([InjectedAction].self, forKey: Key("do")))
        default:
            self = .call(name: try container.decode(String.self, forKey: Key("call")),
                         args: try container.decodeIfPresent([InjectedExpression].self, forKey: Key("args")) ?? [])
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .set(path, value):
            try container.encode(path, forKey: Key("set"))
            try container.encode(value, forKey: Key("to"))
        case let .if(condition, then, otherwise):
            try container.encode(condition, forKey: Key("if"))
            try container.encode(then, forKey: Key("then"))
            if !otherwise.isEmpty { try container.encode(otherwise, forKey: Key("else")) }
        case let .delay(seconds, actions):
            try container.encode(seconds, forKey: Key("delay"))
            try container.encode(actions, forKey: Key("do"))
        case let .call(name, args):
            try container.encode(name, forKey: Key("call"))
            if !args.isEmpty { try container.encode(args, forKey: Key("args")) }
        }
    }
}
