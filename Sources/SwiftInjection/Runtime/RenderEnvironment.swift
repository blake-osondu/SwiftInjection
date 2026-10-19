//
//  RenderEnvironment.swift
//  SwiftInjection
//

import SwiftUI

// MARK: - Environment values

private struct StateStoreKey: EnvironmentKey {
    static let defaultValue = StateStore()
}

private struct ScopeLocalsKey: EnvironmentKey {
    static let defaultValue = ScopeLocals()
}

private struct ViewContainerKey: EnvironmentKey {
    static let defaultValue = ViewStoresContainer(viewStores: [])
}

/// The parameter-slot state, for components that haven't moved to StateStore yet.
private struct LegacyStateSignalKey: EnvironmentKey {
    static let defaultValue = StateSignal(InjectedState.empty)
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

    var viewContainer: ViewStoresContainer {
        get { self[ViewContainerKey.self] }
        set { self[ViewContainerKey.self] = newValue }
    }

    var legacyStateSignal: StateSignal {
        get { self[LegacyStateSignalKey.self] }
        set { self[LegacyStateSignalKey.self] = newValue }
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
    @Environment(\.legacyStateSignal) private var signal
    @Environment(\.viewContainer) private var container

    public init(_ view: InjectedView) {
        self.view = view
    }

    public var body: some View {
        Insertable(stateSignal: signal, container: container, viewStore: view)
    }
}

private struct InjectedModifiers: ViewModifier {
    let modifiers: [InjectedModifier]
    let scope: StateScope
    @Environment(\.legacyStateSignal) private var signal
    @Environment(\.viewContainer) private var container

    func body(content: Content) -> some View {
        content.addModifiers(mods: modifiers, scope: scope, stateSignal: signal, container: container)
    }
}

extension View {
    /// Applies payload modifiers, evaluating their arguments in `scope`.
    func injectedModifiers(_ modifiers: [InjectedModifier], scope: StateScope) -> some View {
        modifier(InjectedModifiers(modifiers: modifiers, scope: scope))
    }
}

// MARK: - Root

/// The entry point: renders `root` (or `container`'s view with id "entry") against `store`.
/// `container` holds views that `{"ref": "id"}` can refer to.
public struct InjectedScreen: View {
    @ObservedObject var store: StateStore
    let root: InjectedView?
    let container: ViewStoresContainer

    public init(store: StateStore, root: InjectedView? = nil, container: ViewStoresContainer = .init(viewStores: [])) {
        self.store = store
        self.root = root
        self.container = container
    }

    public var body: some View {
        InjectedContent(root ?? container.entry ?? .empty())
            .environment(\.stateStore, store)
            .environment(\.viewContainer, container)
    }
}
