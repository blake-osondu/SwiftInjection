import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection

/// Decodes a view payload and renders it as a screen over `state`, collecting reported errors.
/// `views` are extra container views (each with its own "id") that `{"ref": ...}` can use.
struct RenderedScreen {
    let store: StateStore
    let screen: InjectedScreen
    private let errors = ErrorLog()

    init(_ viewJSON: String, state: RuntimeValue = [:], views: [String] = []) throws {
        let decode = { (json: String) in try JSONDecoder().decode(InjectedView.self, from: Data(json.utf8)) }
        store = StateStore(state)
        store.onError = { [errors] in errors.values.append("\($0)") }
        screen = InjectedScreen(store: store, root: try decode(viewJSON),
                                container: ViewStoresContainer(viewStores: try views.map(decode)))
    }

    var reportedErrors: [String] { errors.values }

    func inspect() throws -> InspectableView<ViewType.ClassifiedView> {
        try screen.inspect()
    }

    /// Every Text string in the rendered tree, in order.
    func texts() throws -> [String] {
        try inspect().findAll(ViewType.Text.self).map { try $0.string() }
    }

    final class ErrorLog { var values: [String] = [] }
}
