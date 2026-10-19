//
//  ScriptRuntime.swift
//  SwiftInjection
//

import Foundation
import JavaScriptCore

/// Runs payload scripts in JavaScriptCore and exposes them to the store as host functions.
///
/// Each script is a function expression: `"function (price, currency) { return ... }"` or `"(a, b) => a + b"`.
/// Inside a script:
/// - `state.get("path.to.value")` reads the state the call runs against.
/// - `state.set("path", value)` writes it. Writes are only allowed when the function is called from an action
///   (`{"call": "name", "args": [...]}`); they become part of that action list's transaction.
/// - `console.log(...)` / `log(...)` go to `StateStore.onLog`.
///
/// Arguments, return values and state cross the boundary as JSON, so only JSON-shaped values pass
/// (functions, `undefined` and non-finite numbers become `null`).
///
/// JavaScriptCore has no public execution time limit, so a script that never returns blocks the main thread.
/// Only run payloads you trust (see payload signing in #6).
public final class ScriptRuntime {
    private let context: JSContext
    private var functions: [String: JSValue] = [:]
    /// The state the in-flight call reads and writes.
    private var draft: RuntimeValue = .null
    private var pendingError: EvaluationError?
    var log: (String) -> Void = { print("SwiftInjection script: \($0)") }

    public init() {
        context = JSContext()!
        context.name = "SwiftInjection"
        installHostAPI()
    }

    /// Compiles `source` as a function named `name`. Throws `.script` for syntax errors or non-functions.
    public func define(_ name: String, source: String) throws {
        pendingError = nil
        let value = context.evaluateScript("(\(source)\n)", withSourceURL: URL(string: "swiftinjection://scripts/\(name)"))
        try throwPendingError()
        guard let value, value.isObject, context.objectForKeyedSubscript("Function").map({ value.isInstance(of: $0) }) == true else {
            throw EvaluationError.script("'\(name)' is not a function")
        }
        functions[name] = value
    }

    public var functionNames: [String] { functions.keys.sorted() }

    /// Calls `name` with `args` against `state`, which the script may modify.
    public func call(_ name: String, _ args: [RuntimeValue], state: inout RuntimeValue) throws -> RuntimeValue {
        guard let function = functions[name] else { throw EvaluationError.unknownFunction(name) }
        pendingError = nil
        draft = state
        defer { draft = .null }

        let jsArgs = try args.map(toJS)
        let result = function.call(withArguments: jsArgs)
        try throwPendingError()
        state = draft
        return try result.map(fromJS) ?? .null
    }

    /// Registers every defined function on `store`, so actions and expressions can call them.
    public func install(on store: StateStore) {
        log = { [weak store] message in store?.onLog(message) }
        for name in functions.keys {
            store.functions[name] = { [unowned self] args, state in
                try self.call(name, args, state: &state)
            }
        }
        store.scriptRuntime = self
    }

    // MARK: - Host API

    private func installHostAPI() {
        context.exceptionHandler = { [weak self] _, exception in
            let message = exception?.toString() ?? "unknown error"
            let line = exception?.objectForKeyedSubscript("line")?.toInt32() ?? 0
            self?.pendingError = .script(line > 0 ? "\(message) (line \(line))" : message)
        }

        let get: @convention(block) (String) -> JSValue? = { [weak self] path in
            guard let self else { return nil }
            return try? self.toJS(self.draft.value(at: path.statePath) ?? .null)
        }
        let set: @convention(block) (String, JSValue) -> Void = { [weak self] path, value in
            guard let self else { return }
            do {
                self.draft = self.draft.setting(try self.fromJS(value), at: path.statePath)
            } catch {
                self.pendingError = error as? EvaluationError ?? .script("\(error)")
            }
        }
        let state = JSValue(newObjectIn: context)!
        state.setObject(get, forKeyedSubscript: "get" as NSString)
        state.setObject(set, forKeyedSubscript: "set" as NSString)
        context.setObject(state, forKeyedSubscript: "state" as NSString)

        let log: @convention(block) () -> Void = { [weak self] in
            let message = (JSContext.currentArguments() as? [JSValue] ?? []).map { $0.toString() ?? "" }.joined(separator: " ")
            self?.log(message)
        }
        context.setObject(log, forKeyedSubscript: "log" as NSString)
        let console = JSValue(newObjectIn: context)!
        console.setObject(log, forKeyedSubscript: "log" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)
    }

    private func throwPendingError() throws {
        if let error = pendingError {
            pendingError = nil
            throw error
        }
    }

    // MARK: - Conversion (via JSON)

    private func toJS(_ value: RuntimeValue) throws -> JSValue {
        let json = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        return context.objectForKeyedSubscript("JSON").invokeMethod("parse", withArguments: [json])
    }

    private func fromJS(_ value: JSValue) throws -> RuntimeValue {
        if value.isUndefined || value.isNull { return .null }
        guard let json = context.objectForKeyedSubscript("JSON").invokeMethod("stringify", withArguments: [value]),
              !json.isUndefined, let string = json.toString() else {
            return .null
        }
        do {
            return try JSONDecoder().decode(RuntimeValue.self, from: Data(string.utf8))
        } catch {
            throw EvaluationError.script("Value is not JSON-compatible: \(string)")
        }
    }
}

extension StateStore {
    /// Creates a store with the payload's initial state and its scripts installed.
    /// Script compile errors are reported to `onError` and that function is left undefined.
    public convenience init(payload: InjectedPayload) {
        self.init(payload.state)
        guard !payload.scripts.isEmpty else { return }
        let runtime = ScriptRuntime()
        for (name, source) in payload.scripts.sorted(by: { $0.key < $1.key }) {
            do {
                try runtime.define(name, source: source)
            } catch {
                report(error)
            }
        }
        runtime.install(on: self)
    }
}
