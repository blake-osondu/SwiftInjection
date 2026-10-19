//
//  CustomComponent.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

/// Builds a host-app view for `{"custom": {"name": ...}}`.
///
/// ```swift
/// StateStore.defaultComponents["productCard"] = { context in
///     AnyView(ProductCard(id: context.prop("id") ?? "", onSelect: { context.send("select") }))
/// }
/// ```
public typealias InjectedComponent = (CustomComponentContext) -> AnyView

/// What a registered view receives: its evaluated props and a way to trigger the payload's actions.
public struct CustomComponentContext {
    /// Props evaluated in the current scope. A prop whose expression failed is absent (the error is reported).
    public let props: [String: RuntimeValue]
    let actions: [String: [InjectedAction]]
    let scope: StateScope

    /// A prop converted to `T` (numbers, strings, bools, dates, string-backed enums...). Nil if absent or mistyped.
    public func prop<T: RuntimeConvertible>(_ name: String, as type: T.Type = T.self) -> T? {
        props[name].flatMap { T(runtimeValue: $0) }
    }

    /// Runs the payload's actions for `event` (from `"on": {"event": [...]}`). Unhandled events are ignored.
    public func send(_ event: String) {
        guard let actions = actions[event] else { return }
        scope.perform(actions)
    }

    /// The payload's state, read-only (evaluated in the component's scope, so locals like `item` resolve).
    public func value(at path: String) -> RuntimeValue? {
        scope.value(at: path.statePath)
    }
}

struct CustomInsertable: View {
    let viewStore: CustomViewStore

    var body: some View {
        ScopeReader { scope in
            if let component = scope.store.components[viewStore.name] {
                component(context(scope))
                    .injectedModifiers(viewStore.modifiers, scope: scope)
            } else {
                let _ = scope.store.report(EvaluationError.unknownFunction("component '\(viewStore.name)' (register it in StateStore.components)"))
            }
        }
    }

    private func context(_ scope: StateScope) -> CustomComponentContext {
        var props: [String: RuntimeValue] = [:]
        for (name, expression) in viewStore.props {
            if let value = scope.evaluate(expression) {
                props[name] = value
            }
        }
        return CustomComponentContext(props: props, actions: viewStore.on, scope: scope)
    }
}
