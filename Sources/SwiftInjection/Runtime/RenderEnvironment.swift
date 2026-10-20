//
//  RenderEnvironment.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

// MARK: - Environment values

private struct StateStoreKey: EnvironmentKey {
    static let defaultValue = StateStore()
}

private struct ScopeLocalsKey: EnvironmentKey {
    static let defaultValue = ScopeLocals()
}

private struct InjectedViewsKey: EnvironmentKey {
    static let defaultValue: [String: InjectedView] = [:]
}

extension EnvironmentValues {
    public var stateStore: StateStore {
        get { self[StateStoreKey.self] }
        set { self[StateStoreKey.self] = newValue }
    }

    public var scopeLocals: ScopeLocals {
        get { self[ScopeLocalsKey.self] }
        set { self[ScopeLocalsKey.self] = newValue }
    }

    /// Views that `{"ref": "name"}` can refer to.
    var injectedViews: [String: InjectedView] {
        get { self[InjectedViewsKey.self] }
        set { self[InjectedViewsKey.self] = newValue }
    }
}

// MARK: - Reading state

/// Gives `content` the current StateScope and re-renders it whenever the store changes.
struct ScopeReader<Content: View>: View {
    @Environment(\.stateStore) private var store
    @Environment(\.scopeLocals) private var locals
    let content: (StateScope) -> Content

    init(@ViewBuilder content: @escaping (StateScope) -> Content) {
        self.content = content
    }

    var body: some View {
        Observing(store: store, locals: locals, content: content)
    }

    private struct Observing: View {
        @ObservedObject var store: StateStore
        let locals: ScopeLocals
        let content: (StateScope) -> Content

        var body: some View {
            content(StateScope(store: store, locals: locals))
        }
    }
}

extension View {
    /// Renders child content with additional locals (e.g. a `forEach` item).
    func scopeLocals(_ locals: ScopeLocals) -> some View {
        environment(\.scopeLocals, locals)
    }
}

// MARK: - Rendering children and modifiers

/// Renders a child view from the payload.
public struct InjectedContent: View {
    let view: InjectedView

    public init(_ view: InjectedView) {
        self.view = view
    }

    public var body: some View {
        Insertable(viewStore: view)
    }
}

private struct InjectedModifiers: ViewModifier {
    let modifiers: [InjectedModifier]
    let scope: StateScope

    func body(content: Content) -> some View {
        content.addModifiers(mods: modifiers, scope: scope)
    }
}

extension View {
    /// Applies payload modifiers, evaluating their arguments in `scope`.
    func injectedModifiers(_ modifiers: [InjectedModifier], scope: StateScope) -> some View {
        modifier(InjectedModifiers(modifiers: modifiers, scope: scope))
    }
}

// MARK: - Root

/// Renders a payload against `store`. Create the store with `StateStore(payload:)` (initial state and
/// scripts) and keep it alive, e.g. `@StateObject var store = StateStore(payload: payload)`, so state
/// survives re-renders. Register any Swift host functions on it before showing the screen.
public struct InjectedScreen: View {
    @ObservedObject var store: StateStore
    let root: InjectedView
    let views: [String: InjectedView]

    public init(store: StateStore, payload: InjectedPayload) {
        self.init(store: store, body: payload.body, views: payload.views)
    }

    public init(store: StateStore, body: InjectedView, views: [String: InjectedView] = [:]) {
        self.store = store
        self.root = body
        self.views = views
    }

    public var body: some View {
        InjectedContent(root)
            .environment(\.stateStore, store)
            .environment(\.injectedViews, views)
    }
}

/// Renders a list of child views in order.
public struct InjectedChildren: View {
    let children: [InjectedView]

    public init(_ children: [InjectedView]) {
        self.children = children
    }

    public var body: some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
            InjectedContent(child)
        }
    }
}
