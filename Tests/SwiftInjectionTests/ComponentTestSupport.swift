import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection

/// Decodes a view payload and renders it as a screen over `state`, collecting reported errors.
/// `views` are named views that `{"ref": "name"}` can use.
struct RenderedScreen {
    let store: StateStore
    let screen: InjectedScreen
    private let errors = ErrorLog()

    init(_ viewJSON: String, state: RuntimeValue = [:], views: [String: String] = [:]) throws {
        let decode = { (json: String) in try JSONDecoder().decode(InjectedView.self, from: Data(json.utf8)) }
        store = StateStore(state)
        store.onError = { [errors] in errors.values.append("\($0)") }
        screen = InjectedScreen(store: store, body: try decode(viewJSON), views: try views.mapValues(decode))
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

extension RenderedScreen {
    /// Modifiers are applied to ModifierStore's AnyView wrappers rather than the component's own view,
    /// so run `call` on the first wrapper that carries the modifier.
    func callModifier(_ call: (InspectableView<ViewType.AnyView>) throws -> Void,
                      file: StaticString = #filePath, line: UInt = #line) throws {
        for candidate in try inspect().findAll(ViewType.AnyView.self) {
            if (try? call(candidate)) != nil { return }
        }
        XCTFail("No view carries the modifier", file: file, line: line)
    }
}
