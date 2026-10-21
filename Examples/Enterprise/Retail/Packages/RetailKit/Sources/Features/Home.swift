import SwiftUI
import ComposableArchitecture
import Models
import Clients
import RemoteScreens

/// The storefront. Merchandising changes its layout often, so the view is the remote `Home` screen.
@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var feed: HomeFeed?
        public var loadFailed = false

        public init(feed: HomeFeed? = nil) {
            self.feed = feed
        }
    }

    public enum Action {
        case task
        case feedLoaded(Result<HomeFeed, any Error>)
        case productTapped(id: String)
        case categoryTapped(id: String)
        case searchTapped
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case openProduct(Product)
            case openCatalog(category: String?)
        }
    }

    @Dependency(\.catalog) var catalog

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.feed == nil else { return .none }
                state.loadFailed = false
                return .run { send in
                    await send(.feedLoaded(Result { try await catalog.home() }))
                }
            case .feedLoaded(.success(let feed)):
                state.feed = feed
                return .none
            case .feedLoaded(.failure):
                state.loadFailed = true
                return .none
            case .productTapped(let id):
                guard let product = state.feed.flatMap({ ($0.featured + $0.trending).first { $0.id == id } }) else { return .none }
                return .send(.delegate(.openProduct(product)))
            case .categoryTapped(let id):
                return .send(.delegate(.openCatalog(category: id)))
            case .searchTapped:
                return .send(.delegate(.openCatalog(category: nil)))
            case .delegate:
                return .none
            }
        }
    }
}

public struct HomeView: View {
    let store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        RemoteScreen("Home", state: ["isLoading": store.feed == nil, "feed": store.feed], intents: [
            "openProduct": { store.send(.productTapped(id: $0.string(0))) },
            "openCategory": { store.send(.categoryTapped(id: $0.string(0))) },
            "search": { _ in store.send(.searchTapped) },
        ])
        .task { await store.send(.task).finish() }
    }
}
