//
//  StateScope.swift
//  SwiftInjection
//

import Foundation
import SwiftUI

/// Local names in effect at a point in the view tree, e.g. `item` inside a `forEach`.
public struct ScopeLocals: Hashable {
    public enum Local: Hashable {
        /// An alias for a location in the store; reads and writes go through it.
        case path([String])
        /// A read-only value, such as a loop index.
        case value(RuntimeValue)
    }

    public var locals: [String: Local] = [:]

    public init(_ locals: [String: Local] = [:]) {
        self.locals = locals
    }

    func resolve(_ path: [String], in root: RuntimeValue) -> RuntimeValue? {
        guard let head = path.first, let local = locals[head] else {
            return root.value(at: path)
        }
        switch local {
        case .path(let base):
            return root.value(at: base + path.dropFirst())
        case .value(let value):
            return value.value(at: Array(path.dropFirst()))
        }
    }

    /// The absolute store path a write to `path` targets.
    func writablePath(_ path: [String]) throws -> [String] {
        guard let head = path.first, let local = locals[head] else {
            return path
        }
        switch local {
        case .path(let base):
            return base + path.dropFirst()
        case .value:
            throw EvaluationError.readOnly(path.joined(separator: "."))
        }
    }
}

/// Reads against a state draft, used while an action list runs.
struct DraftScope: ExpressionScope {
    let root: RuntimeValue
    let locals: ScopeLocals

    func value(at path: [String]) -> RuntimeValue? {
        locals.resolve(path, in: root)
    }
}

/// A store plus the locals visible at one point in the view tree. Passed down via the environment.
public struct StateScope: ExpressionScope {
    public let store: StateStore
    public var locals: ScopeLocals
    var evaluator = ExpressionEvaluator()

    public init(store: StateStore, locals: ScopeLocals = .init()) {
        self.store = store
        self.locals = locals
    }

    public func value(at path: [String]) -> RuntimeValue? {
        locals.resolve(path, in: store.root)
    }

    /// A scope where `name` refers to `path` (resolved through the current locals).
    public func child(_ name: String, at path: String) -> StateScope {
        var copy = self
        if let absolute = try? locals.writablePath(path.statePath) {
            copy.locals.locals[name] = .path(absolute)
        } else {
            copy.locals.locals[name] = .value(value(at: path.statePath) ?? .null)
        }
        return copy
    }

    /// A scope where `name` is a read-only value.
    public func child(_ name: String, value: RuntimeValue) -> StateScope {
        var copy = self
        copy.locals.locals[name] = .value(value)
        return copy
    }

    // MARK: Reading

    /// Evaluates for display. Failures are reported to the store and return nil.
    public func evaluate(_ expression: InjectedExpression) -> RuntimeValue? {
        do {
            return try evaluator.evaluate(expression, in: self)
        } catch {
            store.report(error)
            return nil
        }
    }

    public func string(_ expression: InjectedExpression?, default fallback: String = "") -> String {
        guard let expression, let value = evaluate(expression) else { return fallback }
        return value.displayString
    }

    public func bool(_ expression: InjectedExpression?, default fallback: Bool = false) -> Bool {
        guard let expression, case .bool(let value)? = evaluate(expression) else { return fallback }
        return value
    }

    public func number(_ expression: InjectedExpression?, default fallback: Double = 0) -> Double {
        guard let expression, case .number(let value)? = evaluate(expression) else { return fallback }
        return value
    }

    // MARK: Writing

    public func binding(_ path: String) -> Binding<RuntimeValue> {
        Binding(
            get: { value(at: path.statePath) ?? .null },
            set: { newValue in
                do {
                    let target = try locals.writablePath(path.statePath)
                    store.update { $0 = $0.setting(newValue, at: target) }
                } catch {
                    store.report(error)
                }
            })
    }

    public func stringBinding(_ path: String) -> Binding<String> {
        let binding = binding(path)
        return Binding(
            get: { binding.wrappedValue.displayString },
            set: { binding.wrappedValue = .string($0) })
    }

    public func boolBinding(_ path: String) -> Binding<Bool> {
        let binding = binding(path)
        return Binding(
            get: { if case .bool(let value) = binding.wrappedValue { return value } else { return false } },
            set: { binding.wrappedValue = .bool($0) })
    }
}
