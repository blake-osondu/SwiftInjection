import XCTest
import SwiftUI
@testable import SwiftInjection
@testable import SwiftInjectionCore

final class ModifierTests: XCTestCase {

    /// One of every modifier.
    static let allModifiersJSON = #"""
    [
      {"systemFont": {"font": "title"}},
      {"font": {"name": "Helvetica", "size": 14}},
      {"fontWeight": {"weight": "bold"}},
      {"fontDesign": {"design": "rounded"}},
      {"fontWidth": {"width": "condensed"}},
      {"bold": {}},
      {"italic": {"isActive": {"var": "isEmphasized"}}},
      {"monospaced": {"isActive": false}},
      {"monospacedDigit": {}},
      {"kerning": {"value": 1.5}},
      {"tracking": {"value": 2}},
      {"strikethrough": {"pattern": "dash", "color": "#FF0000"}},
      {"underline": {"isActive": true}},
      {"lineLimit": {"limit": 2}},
      {"truncationMode": {"mode": "middle"}},
      {"multilineTextAlignment": {"alignment": "center"}},
      {"minimumScaleFactor": {"factor": 0.5}},
      {"frame": {"width": 100, "maxHeight": "infinity", "alignment": "leading"}},
      {"padding": {"edges": "horizontal", "length": {"var": "spacing"}}},
      {"position": {"x": 10}},
      {"layoutPriority": {"priority": 1}},
      {"fixedSize": {"vertical": true}},
      {"ignoresSafeArea": {}},
      {"foregroundColor": {"color": {"var": "tint"}}},
      {"background": {"content": {"empty": {"id": ""}}, "alignment": "top"}},
      {"cornerRadius": {"radius": 8}},
      {"border": {"color": "#000000", "width": 2}},
      {"opacity": {"value": {"if": [{"var": "isEmphasized"}, 1, 0.5]}}},
      {"shadow": {"radius": 4, "y": 2}},
      {"blur": {"radius": 3}},
      {"brightness": {"amount": 0.1}},
      {"blendMode": {"mode": "multiply"}},
      {"colorInvert": {}},
      {"colorMultiply": {"color": "#00FF00"}},
      {"symbolRenderingMode": {"mode": "hierarchical"}},
      {"imageScale": {"scale": "large"}},
      {"unredacted": {}},
      {"animation": {"animation": "easeIn", "value": {"var": "count"}}},
      {"sheet": {"isPresented": "showSheet", "content": {"empty": {"id": ""}}}},
      {"fullScreenCover": {"isPresented": "showCover", "content": {"empty": {"id": ""}}}},
      {"popover": {"isPresented": "showPopover", "arrowEdge": "bottom", "content": {"empty": {"id": ""}}}},
      {"alert": {"isPresented": "showAlert", "alert": {"title": "Hi", "message": {"var": "count"}, "buttons": [{"label": "OK", "action": [{"set": "count", "to": 0}]}]}}},
      {"navigationTitle": {"title": {"var": "count"}}},
      {"confirmationDialog": {"isPresented": "showDialog", "title": "Sure?", "actions": {"empty": {"id": ""}}}},
      {"disabled": {"isDisabled": {"gt": [{"var": "count"}, 3]}}},
      {"buttonStyle": {"style": "borderedProminent"}},
      {"pickerStyle": {"style": "segmented"}},
      {"datePickerStyle": {"style": "compact"}},
      {"tag": {"value": 3}},
      {"badge": {"value": "new"}},
      {"tabItem": {"content": {"empty": {"id": ""}}}},
      {"keyboardType": {"type": "numberPad"}},
      {"autocorrectionDisabled": {}},
      {"textInputAutocapitalization": {"mode": "never"}},
      {"textContentType": {"type": "emailAddress"}},
      {"onAppear": {"do": [{"set": "appeared", "to": true}]}},
      {"onDisappear": {"do": []}},
      {"onTapGesture": {"count": 2, "do": []}},
      {"onChange": {"of": {"var": "count"}, "do": []}},
      {"onSubmit": {"do": []}},
      {"antialiased": {"isActive": true}},
      {"resizable": {"resizingMode": "tile"}},
      {"renderingMode": {"mode": "template"}},
      {"path": {"width": 10, "height": 10}}
    ]
    """#

    func testEveryModifierDecodesAndRoundTrips() throws {
        let modifiers = try JSONDecoder().decode([InjectedModifier].self, from: Data(Self.allModifiersJSON.utf8))
        XCTAssertEqual(modifiers.count, 64)
        let reencoded = try JSONEncoder().encode(modifiers)
        XCTAssertEqual(try JSONDecoder().decode([InjectedModifier].self, from: reencoded).count, 64)
    }

    func testPaddingDecodesToExpressions() throws {
        let modifier = try JSONDecoder().decode(InjectedModifier.self, from: Data(#"{"padding": {"edges": "horizontal", "length": {"var": "spacing"}}}"#.utf8))
        guard case let .padding(edges, length) = modifier else { return XCTFail("\(modifier)") }
        XCTAssertEqual(edges, "horizontal")
        XCTAssertEqual(length, .var("spacing"))
    }

    func testMissingRequiredArgumentFailsToDecode() {
        XCTAssertThrowsError(try JSONDecoder().decode(InjectedModifier.self, from: Data(#"{"cornerRadius": {}}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(InjectedModifier.self, from: Data(#"{"spacingBetweenText": {"spacing": 1}}"#.utf8)))
    }

    // MARK: resolve

    func testResolveConvertsTypes() {
        let scope = StateScope(store: StateStore(["n": 2.5, "i": 3, "edge": "leading", "max": "infinity", "on": true]))
        XCTAssertEqual(scope.resolve(.var("n"), as: Double.self), 2.5)
        XCTAssertEqual(scope.resolve(.var("i"), as: Int.self), 3)
        XCTAssertEqual(scope.resolve(.var("max"), as: CGFloat.self), .infinity)
        XCTAssertEqual(scope.resolve(.var("on"), as: Bool.self), true)
        XCTAssertEqual(scope.resolve(.var("edge"), as: InjectedEdgeSet.self), .leading)
        XCTAssertEqual(scope.resolve(nil, as: Double.self), nil)
    }

    func testResolveReportsMismatches() {
        let store = StateStore(["n": 2.5, "edge": "sideways"])
        var errors: [EvaluationError] = []
        store.onError = { errors.append($0 as! EvaluationError) }
        let scope = StateScope(store: store)

        XCTAssertNil(scope.resolve(.var("n"), as: Int.self))           // not integral
        XCTAssertNil(scope.resolve(.var("edge"), as: InjectedEdgeSet.self))  // unknown raw value
        XCTAssertNil(scope.resolve(.var("missing"), as: Double.self))
        XCTAssertEqual(errors, [
            .typeMismatch(op: "resolve", expected: "integer", got: "2.5"),
            .typeMismatch(op: "resolve", expected: "InjectedEdgeSet", got: "sideways"),
            .unknownVariable("missing"),
        ])
    }

    // MARK: rendering

    /// Renders `modifiers` on a Text in a real window and returns every error reported while rendering.
    private func render(_ modifiers: [InjectedModifier], state: RuntimeValue) -> [String] {
        var errors: [String] = []
        let store = StateStore(state)
        store.onError = { errors.append("\($0)") }
        var text = TextViewStore(value: "Hello")
        text.modifiers = modifiers

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = UIHostingController(rootView: InjectedScreen(store: store, body: .text(viewStore: text)))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        window.isHidden = true
        return errors
    }

    func testRenderReportsInvalidOptionValues() throws {
        let modifiers = try JSONDecoder().decode([InjectedModifier].self, from: Data(#"[{"blendMode": {"mode": "sparkly"}}]"#.utf8))
        XCTAssertEqual(render(modifiers, state: [:]),
                       [EvaluationError.typeMismatch(op: "resolve", expected: "InjectedBlendMode", got: "sparkly").description])
    }

    func testRendersEveryModifierWithoutErrors() throws {
        let modifiers = try JSONDecoder().decode([InjectedModifier].self, from: Data(Self.allModifiersJSON.utf8))
        let state: RuntimeValue = ["spacing": 12, "tint": "#3366FF", "isEmphasized": true, "count": 5,
                                   "showSheet": false, "showCover": false, "showPopover": false, "showDialog": false, "showAlert": false]
        XCTAssertEqual(render(modifiers, state: state), [])
    }
}
