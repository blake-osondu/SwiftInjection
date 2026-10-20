//
//  RemoteInjectedScreen.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

/// When a newer remote payload is applied once a screen is already showing.
public enum PayloadUpdatePolicy {
    /// Cache it and use it the next time the screen is created (default). Avoids resetting state mid-use.
    case nextLaunch
    /// Replace the showing screen as soon as it arrives. The screen's state resets to the new payload's.
    case immediately
}

/// Drives a `RemoteInjectedScreen`: shows the cached or bundled payload at once, then checks the network.
@MainActor
public final class RemotePayloadModel: ObservableObject {
    @Published public private(set) var store: StateStore?
    @Published public private(set) var payload: InjectedPayload?
    @Published public private(set) var source: PayloadLoader.Source?
    @Published public private(set) var error: PayloadError?
    /// Increments each time a payload is shown, so the screen is rebuilt rather than diffed. A swapped-in payload
    /// brings new state, and reusing the old view tree can leave stale UI (e.g. a navigation title).
    @Published public private(set) var generation = 0

    private let loader: PayloadLoader
    private let updatePolicy: PayloadUpdatePolicy
    private let configureStore: (StateStore) -> Void
    private var started = false

    public init(loader: PayloadLoader, updatePolicy: PayloadUpdatePolicy = .nextLaunch,
                configureStore: @escaping (StateStore) -> Void = { _ in }) {
        self.loader = loader
        self.updatePolicy = updatePolicy
        self.configureStore = configureStore
    }

    public func start() async {
        guard !started else { return }
        started = true

        if let local = try? loader.loadLocal() {
            show(local)
        }
        do {
            let remote = try await loader.loadRemote()
            let isNewer = payload == nil || remote.payload.version == nil || remote.payload.version != payload?.version
            if payload == nil || (updatePolicy == .immediately && isNewer) {
                show(remote)
            }
        } catch {
            if payload == nil {
                self.error = error as? PayloadError ?? .network("\(error)")
            }
        }
    }

    private func show(_ loaded: PayloadLoader.Loaded) {
        let store = StateStore(payload: loaded.payload)
        for warning in loaded.warnings {
            store.onLog("warning: \(warning)")
        }
        configureStore(store)
        self.store = store
        self.payload = loaded.payload
        self.source = loaded.source
        self.error = nil
        generation += 1
    }
}

/// Loads a payload with `PayloadLoader` and renders it.
///
/// ```swift
/// RemoteInjectedScreen(loader: loader) { store in
///     store.functions["openURL"] = { args, _ in … }
/// }
/// ```
public struct RemoteInjectedScreen<Placeholder: View, Failure: View>: View {
    @StateObject private var model: RemotePayloadModel
    private let placeholder: () -> Placeholder
    private let failure: (PayloadError) -> Failure

    public init(loader: PayloadLoader,
                updatePolicy: PayloadUpdatePolicy = .nextLaunch,
                configureStore: @escaping (StateStore) -> Void = { _ in },
                @ViewBuilder placeholder: @escaping () -> Placeholder,
                @ViewBuilder failure: @escaping (PayloadError) -> Failure) {
        _model = StateObject(wrappedValue: RemotePayloadModel(loader: loader, updatePolicy: updatePolicy, configureStore: configureStore))
        self.placeholder = placeholder
        self.failure = failure
    }

    public var body: some View {
        Group {
            if let store = model.store, let payload = model.payload {
                InjectedScreen(store: store, payload: payload)
                    .id(model.generation)
            } else if let error = model.error {
                failure(error)
            } else {
                placeholder()
            }
        }
        .task { await model.start() }
    }
}

extension RemoteInjectedScreen where Placeholder == ProgressView<EmptyView, EmptyView>, Failure == Text {
    /// Shows a spinner while loading and the error's description if nothing could be loaded.
    public init(loader: PayloadLoader,
                updatePolicy: PayloadUpdatePolicy = .nextLaunch,
                configureStore: @escaping (StateStore) -> Void = { _ in }) {
        self.init(loader: loader, updatePolicy: updatePolicy, configureStore: configureStore,
                  placeholder: { ProgressView() }, failure: { Text($0.description) })
    }
}
