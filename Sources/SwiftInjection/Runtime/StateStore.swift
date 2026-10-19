//
//  StateStore.swift
//  SwiftInjection
//

import Foundation
import Combine

/// The single source of truth for a screen's state. Use from the main thread.
public final class StateStore: ObservableObject {
    /// A function the payload can invoke with `{"call": "name", "args": [...]}`.
    /// It receives the evaluated arguments and may mutate the state draft it is given.
    public typealias HostFunction = (_ args: [RuntimeValue], _ state: inout RuntimeValue) throws -> RuntimeValue

    @Published public private(set) var root: RuntimeValue
    public var functions: [String: HostFunction] = [:]
    /// Called for evaluation and action failures. Defaults to logging.
    public var onError: (Error) -> Void = { print("SwiftInjection: \($0)") }

    public init(_ root: RuntimeValue = [:]) {
        self.root = root
    }

    public func value(at path: [String]) -> RuntimeValue? {
        root.value(at: path)
    }

    /// Applies `body` to a copy of the state and publishes the result once.
    /// If `body` throws, nothing is published.
    public func update(_ body: (inout RuntimeValue) throws -> Void) rethrows {
        var draft = root
        try body(&draft)
        if draft != root {
            root = draft
        }
    }

    func report(_ error: Error) {
        onError(error)
    }
}

extension String {
    /// `"todos.0.title"` → `["todos", "0", "title"]`
    var statePath: [String] {
        split(separator: ".").map(String.init)
    }
}
