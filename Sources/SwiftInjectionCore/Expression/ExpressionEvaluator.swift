//
//  ExpressionEvaluator.swift
//  SwiftInjection
//

import Foundation

/// Anything expressions can read variables from.
public protocol ExpressionScope {
    func value(at path: [String]) -> RuntimeValue?
    /// Invokes a host function for `{"call": ["name", args...]}`. Calls from expressions must not change state.
    func call(_ name: String, _ args: [RuntimeValue]) throws -> RuntimeValue
}

extension ExpressionScope {
    public func call(_ name: String, _ args: [RuntimeValue]) throws -> RuntimeValue {
        throw EvaluationError.unknownFunction(name)
    }
}

extension RuntimeValue: ExpressionScope {}

public enum EvaluationError: Error, Equatable, CustomStringConvertible {
    case unknownVariable(String)
    case typeMismatch(op: String, expected: String, got: String)
    case arity(op: String, expected: String, got: Int)
    case divisionByZero
    case indexOutOfRange(Int)
    case tooDeep(limit: Int)
    case script(String)
    case readOnly(String)
    case unknownFunction(String)

    public var description: String {
        switch self {
        case .unknownVariable(let path): return "Unknown variable '\(path)'"
        case let .typeMismatch(op, expected, got): return "'\(op)' expected \(expected), got \(got)"
        case let .arity(op, expected, got): return "'\(op)' expected \(expected) argument(s), got \(got)"
        case .divisionByZero: return "Division by zero"
        case .indexOutOfRange(let index): return "Index \(index) is out of range"
        case .tooDeep(let limit): return "Expression nesting exceeds \(limit) levels"
        case .script(let message): return "Script error: \(message)"
        case .readOnly(let path): return "'\(path)' is read-only"
        case .unknownFunction(let name): return "Unknown function '\(name)'"
        }
    }
}

public struct ExpressionEvaluator {
    public var maxDepth: Int

    public init(maxDepth: Int = 128) {
        self.maxDepth = maxDepth
    }

    public func evaluate(_ expression: InjectedExpression, in scope: ExpressionScope) throws -> RuntimeValue {
        try evaluate(expression, scope, depth: 0)
    }

    /// Evaluates a condition, requiring a boolean result.
    public func condition(_ expression: InjectedExpression, in scope: ExpressionScope) throws -> Bool {
        let value = try evaluate(expression, in: scope)
        guard case .bool(let result) = value else {
            throw EvaluationError.typeMismatch(op: "condition", expected: "bool", got: value.typeName)
        }
        return result
    }

    private func evaluate(_ expression: InjectedExpression, _ scope: ExpressionScope, depth: Int) throws -> RuntimeValue {
        guard depth < maxDepth else { throw EvaluationError.tooDeep(limit: maxDepth) }
        let next = { (child: InjectedExpression) in try evaluate(child, scope, depth: depth + 1) }

        switch expression {
        case .literal(let value):
            return value
        case .array(let elements):
            return .array(try elements.map(next))
        case .object(let fields):
            return .object(try fields.mapValues(next))
        case let .variable(path, fallback):
            if let value = scope.value(at: path.split(separator: ".").map(String.init)) {
                return value
            }
            if let fallback { return try next(fallback) }
            throw EvaluationError.unknownVariable(path)
        case let .operation(op, args):
            return try apply(op, args, scope, next)
        }
    }

    private func apply(_ op: InjectedExpression.Operator,
                       _ args: [InjectedExpression],
                       _ scope: ExpressionScope,
                       _ eval: (InjectedExpression) throws -> RuntimeValue) throws -> RuntimeValue {
        let name = op.rawValue

        func arity(_ count: Int) throws {
            guard args.count == count else { throw EvaluationError.arity(op: name, expected: "\(count)", got: args.count) }
        }
        func number(_ value: RuntimeValue) throws -> Double {
            guard case .number(let n) = value else { throw EvaluationError.typeMismatch(op: name, expected: "number", got: value.typeName) }
            return n
        }
        func bool(_ value: RuntimeValue) throws -> Bool {
            guard case .bool(let b) = value else { throw EvaluationError.typeMismatch(op: name, expected: "bool", got: value.typeName) }
            return b
        }
        func numbers() throws -> [Double] { try args.map { try number(eval($0)) } }
        func compare(_ predicate: (ComparisonResult) -> Bool) throws -> RuntimeValue {
            try arity(2)
            switch (try eval(args[0]), try eval(args[1])) {
            case let (.number(a), .number(b)):
                return .bool(predicate(a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame))
            case let (.string(a), .string(b)):
                return .bool(predicate(a.compare(b)))
            case let (a, b):
                throw EvaluationError.typeMismatch(op: name, expected: "two numbers or two strings", got: "\(a.typeName), \(b.typeName)")
            }
        }

        switch op {
        case .add:
            return .number(try numbers().reduce(0, +))
        case .mul:
            return .number(try numbers().reduce(1, *))
        case .sub:
            let values = try numbers()
            switch values.count {
            case 1: return .number(-values[0])
            case 2: return .number(values[0] - values[1])
            default: throw EvaluationError.arity(op: name, expected: "1 or 2", got: values.count)
            }
        case .div, .mod:
            try arity(2)
            let values = try numbers()
            guard values[1] != 0 else { throw EvaluationError.divisionByZero }
            return .number(op == .div ? values[0] / values[1] : values[0].truncatingRemainder(dividingBy: values[1]))

        case .eq, .neq:
            try arity(2)
            let equal = try eval(args[0]) == eval(args[1])
            return .bool(op == .eq ? equal : !equal)
        case .gt: return try compare { $0 == .orderedDescending }
        case .gte: return try compare { $0 != .orderedAscending }
        case .lt: return try compare { $0 == .orderedAscending }
        case .lte: return try compare { $0 != .orderedDescending }

        case .and:
            for arg in args where try !bool(eval(arg)) { return false }
            return true
        case .or:
            for arg in args where try bool(eval(arg)) { return true }
            return false
        case .not:
            try arity(1)
            return .bool(try !bool(eval(args[0])))
        case .if:
            try arity(3)
            return try eval(bool(eval(args[0])) ? args[1] : args[2])

        case .concat:
            return .string(try args.map { try eval($0).displayString }.joined())
        case .format:
            guard let first = args.first else { throw EvaluationError.arity(op: name, expected: "at least 1", got: 0) }
            guard case .string(var template) = try eval(first) else {
                throw EvaluationError.typeMismatch(op: name, expected: "string template", got: try eval(first).typeName)
            }
            for (index, arg) in args.dropFirst().enumerated() {
                template = template.replacingOccurrences(of: "{\(index)}", with: try eval(arg).displayString)
            }
            return .string(template)
        case .length, .count:
            try arity(1)
            switch try eval(args[0]) {
            case .string(let s): return .number(Double(s.count))
            case .array(let a): return .number(Double(a.count))
            case .object(let o): return .number(Double(o.count))
            case let other: throw EvaluationError.typeMismatch(op: name, expected: "string, array or object", got: other.typeName)
            }
        case .at:
            try arity(2)
            switch (try eval(args[0]), try eval(args[1])) {
            case let (.array(values), .number(index)):
                guard let i = Int(exactly: index), values.indices.contains(i) else {
                    throw EvaluationError.indexOutOfRange(Int(index))
                }
                return values[i]
            case let (.object(fields), .string(key)):
                return fields[key] ?? .null
            case let (a, b):
                throw EvaluationError.typeMismatch(op: name, expected: "(array, number) or (object, string)", got: "\(a.typeName), \(b.typeName)")
            }
        case .call:
            guard let first = args.first else { throw EvaluationError.arity(op: name, expected: "at least 1", got: 0) }
            guard case .string(let function) = try eval(first) else {
                throw EvaluationError.typeMismatch(op: name, expected: "function name", got: try eval(first).typeName)
            }
            return try scope.call(function, try args.dropFirst().map(eval))
        }
    }
}
