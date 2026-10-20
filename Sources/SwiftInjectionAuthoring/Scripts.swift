//
//  Scripts.swift
//  SwiftInjectionAuthoring
//

import Foundation

// Functions screens use to call payload scripts. They let the screen build normally in Xcode (and render in
// Previews with a placeholder); `swift-injection compile` turns each call into a call to the JavaScript
// function of that name in the screen's `.scripts.js` file.

/// A display value computed by the script `name`, e.g. `Text(script("formatPrice", price))`.
/// Previews show `‹name›`.
public func script(_ name: String, _ arguments: Any...) -> String {
    "‹\(name)›"
}

/// A value of another type computed by the script `name`; Previews use `placeholder`.
/// `.opacity(script("fade", progress, placeholder: 1.0))`
public func script<Value>(_ name: String, _ arguments: Any..., placeholder: Value) -> Value {
    placeholder
}

/// Runs the script `name` from an action, e.g. `Button("Add") { runScript("addTodo", draft) }`.
/// The script can read and write state with `state.get` / `state.set`. Does nothing in Previews.
public func runScript(_ name: String, _ arguments: Any...) {}

// Functions screens use to call Swift functions the host app registers in `StateStore.functions` (navigation,
// analytics, feature flags, …). Unlike scripts, they need no JavaScript; the app must register them.

/// Runs the host function `name` from an action, e.g. `Button("Open") { hostAction("navigate", "offers") }`.
/// Does nothing in Previews.
public func hostAction(_ name: String, _ arguments: Any...) {}

/// A value from the host function `name`, e.g. `if hostValue("featureEnabled", "newOffers", placeholder: false) { … }`.
/// Previews use `placeholder`. Host functions called from expressions can't change state.
public func hostValue<Value>(_ name: String, _ arguments: Any..., placeholder: Value) -> Value {
    placeholder
}
