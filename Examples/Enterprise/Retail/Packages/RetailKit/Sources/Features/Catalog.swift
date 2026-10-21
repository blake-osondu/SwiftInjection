import SwiftUI
import ComposableArchitecture
import Models
import Clients
import RemoteScreens

/// Search and browse. The remote `Catalog` screen owns only the search field's text; it sends each change here,
/// and the results, filters and sort order are this feature's state.
@Reducer
public struct CatalogFeature {
    @ObservableState
    public struct State: Equatable {
        public var query = ""
        public var category: String?
        public var sort: ProductSort = .featured
        public var results: [Product] = []
        public var isSearching = false
        public var hasSearched = false

        public init(category: String? = nil) {
            self.category = category
        }
    }

    public enum Action {
        case task
        case queryChanged(String)
        case categoryTapped(String)
        case sortTapped(ProductSort)
        case resultsLoaded(Result<[Product], any Error>)
        case productTapped(id: String)
        case delegate(Delegate)

        @CasePathable

        public enum Delegate: Equatable {
            case openProduct(Product)
        }
    }

    enum CancelID { case search }

    @Dependency(\.catalog) var catalog
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return state.hasSearched ? .none : search(&state)
            case .queryChanged(let query):
                guard query != state.query else { return .none }
                state.query = query
                return search(&state, debounce: true)
            case .categoryTapped(let category):
                // Tapping the selected category clears it.
                state.category = state.category == category ? nil : category
                return search(&state)
            case .sortTapped(let sort):
                state.sort = sort
                return search(&state)
            case .resultsLoaded(.success(let results)):
                state.isSearching = false
                state.hasSearched = true
                state.results = results
                return .none
            case .resultsLoaded(.failure):
                state.isSearching = false
                return .none
            case .productTapped(let id):
                guard let product = state.results.first(where: { $0.id == id }) else { return .none }
                return .send(.delegate(.openProduct(product)))
            case .delegate:
                return .none
            }
        }
    }

    private func search(_ state: inout State, debounce: Bool = false) -> Effect<Action> {
        state.isSearching = true
        return .run { [query = state.query, category = state.category, sort = state.sort] send in
            if debounce { try await clock.sleep(for: .milliseconds(250)) }
            await send(.resultsLoaded(Result { try await catalog.search(query, category, sort) }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}

public struct CatalogView: View {
    let store: StoreOf<CatalogFeature>

    public init(store: StoreOf<CatalogFeature>) {
        self.store = store
    }

    public var body: some View {
        RemoteScreen("Catalog", state: [
            "results": store.results,
            "category": store.category ?? "",
            "sort": store.sort.rawValue,
            "isSearching": store.isSearching,
            "categories": Catalog.categories,
        ], intents: [
            "search": { store.send(.queryChanged($0.string(0))) },
            "selectCategory": { store.send(.categoryTapped($0.string(0))) },
            "sort": { store.send(.sortTapped(ProductSort(rawValue: $0.string(0)) ?? .featured)) },
            "openProduct": { store.send(.productTapped(id: $0.string(0))) },
        ])
        .task { await store.send(.task).finish() }
    }
}
