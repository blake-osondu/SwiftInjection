import XCTest
@testable import SwiftInjectionCompiler
@testable import SwiftInjectionCore

final class CompilerTests: XCTestCase {

    // MARK: helpers

    /// Compiles `source`, failing the test on any diagnostic.
    private func compile(_ source: String, file: StaticString = #filePath, line: UInt = #line) throws -> InjectedPayload {
        let result = SwiftUICompiler.compile(source: source, fileName: "Screen.swift")
        XCTAssertEqual(result.diagnostics.map(\.description), [], file: file, line: line)
        return try XCTUnwrap(result.payload, file: file, line: line)
    }

    /// The body of a one-view screen with the given state and body.
    private func screen(state: String = "", _ body: String) -> String {
        """
        import SwiftUI

        struct Screen: View {
            \(state)
            var body: some View {
                \(body)
            }
        }
        """
    }

    private func diagnostics(_ source: String) -> [String] {
        SwiftUICompiler.compile(source: source, fileName: "Screen.swift").diagnostics.map(\.description)
    }

    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    /// Encodes `view` the way the payload encoder does, for comparing with expected JSON.
    private func assertBody(_ payload: InjectedPayload, equals expected: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expectedView = try JSONDecoder().decode(InjectedView.self, from: Data(expected.utf8))
        XCTAssertEqual(try json(payload.body), try json(expectedView), file: file, line: line)
    }

    // MARK: acceptance: the counter screen

    func testCounterScreenCompilesToTheHandWrittenPayload() throws {
        let source = """
        import SwiftUI

        struct Counter: View {
            @State private var count = 0

            var body: some View {
                VStack(spacing: 8) {
                    Text("Tapped \\(count) times")
                    Button("Tap") { count += 1 }
                    if count >= 10 {
                        Text("Double digits!")
                    }
                }
            }
        }
        """
        let expected = #"""
        {
          "schemaVersion": "1.0",
          "state": { "count": 0 },
          "body": { "vStack": { "spacing": 8, "children": [
            { "text": { "value": { "format": ["Tapped {0} times", { "var": "count" }] } } },
            { "button": { "title": "Tap", "action": [ { "set": "count", "to": { "add": [{ "var": "count" }, 1] } } ] } },
            { "if": { "condition": { "gte": [{ "var": "count" }, 10] }, "then": { "text": { "value": "Double digits!" } } } }
          ]}}
        }
        """#
        let compiled = try compile(source)
        let handWritten = try JSONDecoder().decode(InjectedPayload.self, from: Data(expected.utf8))
        XCTAssertEqual(try json(compiled), try json(handWritten))

        // And the output loads exactly as the app would load it.
        let output = try XCTUnwrap(try SwiftUICompiler.compile(source: source).json())
        XCTAssertNoThrow(try PayloadValidator().validate(output, signature: nil))
    }

    // MARK: state

    func testStateTypesAndInitialValues() throws {
        let payload = try compile(screen(state: """
        @State var count = 0
            @State var price: Double = 2
            @State var name = "Ada"
            @State var isOn = false
            @State var tags = ["a", "b"]
            @State var user = ["name": "Ada", "age": 36] as [String: Any]
        """, "Text(name)"))
        XCTAssertEqual(payload.state, ["count": 0, "price": 2, "name": "Ada", "isOn": false, "tags": ["a", "b"], "user": ["name": "Ada", "age": 36]])
    }

    func testStateMustBeLiteral() {
        XCTAssertEqual(diagnostics(screen(state: "@State var a = 1\n    @State var b = a + 1", "Text(\"x\")")),
                       ["Screen.swift:5:20: error: Unknown name 'a': expressions can use @State properties and literals"])
        XCTAssertEqual(diagnostics(screen(state: "@State var a: String = 1", "Text(\"x\")")),
                       ["Screen.swift:4:28: error: 'a' is declared String but initialized with a Int"])
        XCTAssertEqual(diagnostics(screen(state: "let title = \"x\"", "Text(title)")),
                       ["Screen.swift:4:5: error: Only @State properties are supported in v1; 'title' isn't one",
                        "Screen.swift:6:14: error: Unknown name 'title': expressions can use @State properties and literals"])
    }

    // MARK: expressions

    func testExpressions() throws {
        let payload = try compile(screen(state: "@State var a = 1\n    @State var b = 2.5\n    @State var s = \"x\"\n    @State var items = [1, 2]\n    @State var on = true", """
        VStack {
                    Text("\\(a + 1) \\(s + "!") \\(String(a) + s)")
                    Text(a > 1 && !on ? "big" : "small")
                    Text("\\(items.count) \\(items.isEmpty) \\(items[0]) \\(b / 2) \\(-a)")
                }
        """))
        try assertBody(payload, equals: #"""
        {"vStack": {"children": [
          {"text": {"value": {"format": ["{0} {1} {2}", {"add": [{"var": "a"}, 1]}, {"concat": [{"var": "s"}, "!"]},
                                          {"concat": [{"concat": [{"var": "a"}]}, {"var": "s"}]}]}}},
          {"text": {"value": {"if": [{"and": [{"gt": [{"var": "a"}, 1]}, {"not": {"var": "on"}}]}, "big", "small"]}}},
          {"text": {"value": {"format": ["{0} {1} {2} {3} {4}", {"count": {"var": "items"}}, {"eq": [{"count": {"var": "items"}}, 0]},
                                          {"var": "items.0"}, {"div": [{"var": "b"}, 2]}, {"sub": {"var": "a"}}]}}}
        ]}}
        """#)
    }

    func testIntegerDivisionIsRejected() {
        XCTAssertEqual(diagnostics(screen(state: "@State var a = 7", "Text(\"\\(a / 2)\")")),
                       ["Screen.swift:6:17: error: Integer division isn't supported (it would round differently at runtime); make one side a Double"])
    }

    func testTypeErrors() {
        XCTAssertEqual(diagnostics(screen(state: "@State var s = \"x\"", "Text(s - 1 == 0 ? \"a\" : \"b\")")),
                       ["Screen.swift:6:14: error: '-' needs a number, got a String"])
        XCTAssertEqual(diagnostics(screen(state: "@State var n = 1", "Text(n ? \"a\" : \"b\")")),
                       ["Screen.swift:6:14: error: '?:' needs a Bool, got a Int"])
    }

    // MARK: actions

    func testActions() throws {
        let payload = try compile(screen(state: "@State var n = 0\n    @State var on = false\n    @State var user = [\"name\": \"\"]\n    @State var label = \"\"", """
        Button("Go") {
                    n += 2
                    n -= 1
                    n *= 3
                    on.toggle()
                    user["name"] = "Ada"
                    if n > 5 {
                        label = "big"
                    } else if n > 2 {
                        label = "medium"
                    } else {
                        label = "small"
                    }
                    label += "!"
                }
        """))
        try assertBody(payload, equals: #"""
        {"button": {"title": "Go", "action": [
          {"set": "n", "to": {"add": [{"var": "n"}, 2]}},
          {"set": "n", "to": {"sub": [{"var": "n"}, 1]}},
          {"set": "n", "to": {"mul": [{"var": "n"}, 3]}},
          {"set": "on", "to": {"not": {"var": "on"}}},
          {"set": "user.name", "to": "Ada"},
          {"if": {"gt": [{"var": "n"}, 5]}, "then": [{"set": "label", "to": "big"}],
           "else": [{"if": {"gt": [{"var": "n"}, 2]}, "then": [{"set": "label", "to": "medium"}], "else": [{"set": "label", "to": "small"}]}]},
          {"set": "label", "to": {"concat": [{"var": "label"}, "!"]}}
        ]}}
        """#)
    }

    func testActionErrors() {
        XCTAssertEqual(diagnostics(screen(state: "@State var n = 0", "Button(\"Go\") { print(n) }")),
                       ["Screen.swift:6:24: error: Unsupported statement in an action: 'print(n)'"])
        XCTAssertEqual(diagnostics(screen(state: "@State var n = 0", "Button(\"Go\") { n + 1 = 2 }")),
                       ["Screen.swift:6:24: error: Only @State properties (and literal subscripts of them) can be assigned"])
        XCTAssertEqual(diagnostics(screen(state: "@State var n = 0", "Button(\"Go\") { let x = 1 }")),
                       ["Screen.swift:6:24: error: Declarations aren't supported in actions; assign @State properties directly"])
    }

    // MARK: views

    func testViewsAndButtons() throws {
        let payload = try compile(screen(state: "@State var n = 0", """
        NavigationStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "star.fill")
                            Image("logo")
                            Label("Settings", systemImage: "gear")
                            Spacer(minLength: 8)
                            Divider()
                        }
                        ZStack(alignment: .topLeading) {
                            Color.blue
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                            Circle()
                            Capsule()
                        }
                        Form {
                            Section("Account") { Text("a") }
                        }
                        Button(role: .destructive) { n = 0 } label: { Label("Reset", systemImage: "trash") }
                        Button(action: { n += 1 }) { Text("Add") }
                    }
                }
        """))
        try assertBody(payload, equals: #"""
        {"navigationStack": {"root": {"scrollView": {"axes": "horizontal", "showsIndicators": false, "children": [
          {"hStack": {"alignment": "top", "spacing": 4, "children": [
            {"image": {"systemName": "star.fill"}}, {"image": {"name": "logo"}},
            {"label": {"title": "Settings", "systemImage": "gear"}}, {"spacer": {"minLength": 8}}, {"divider": {}}]}},
          {"zStack": {"alignment": "topLeading", "children": [
            {"color": {"color": "#FF007AFF"}}, {"roundedRectangle": {"cornerRadius": 12, "style": "continuous"}},
            {"circle": {}}, {"capsule": {}}]}},
          {"form": {"children": [{"section": {"title": "Account", "children": [{"text": {"value": "a"}}]}}]}},
          {"button": {"role": "destructive", "label": {"label": {"title": "Reset", "systemImage": "trash"}}, "action": [{"set": "n", "to": 0}]}},
          {"button": {"label": {"text": {"value": "Add"}}, "action": [{"set": "n", "to": {"add": [{"var": "n"}, 1]}}]}}
        ]}}}}
        """#)
    }

    func testMultipleBodyViewsBecomeAGroupAndIfElseViews() throws {
        let payload = try compile(screen(state: "@State var on = true", """
        if on { Text("on") } else { Text("off") }
                Text("always")
        """))
        try assertBody(payload, equals: #"""
        {"group": {"children": [
          {"if": {"condition": {"var": "on"}, "then": {"text": {"value": "on"}}, "else": {"text": {"value": "off"}}}},
          {"text": {"value": "always"}}]}}
        """#)
    }

    // MARK: modifiers

    func testModifiers() throws {
        let payload = try compile(screen(state: "@State var n = 0\n    @State var busy = false", """
        Text("Hi")
                    .font(.title)
                    .fontWeight(.semibold)
                    .bold()
                    .foregroundColor(.red.opacity(0.5))
                    .padding()
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 1, green: 0.5, blue: 0))
                    .cornerRadius(8)
                    .shadow(radius: 4, y: 2)
                    .opacity(busy ? 0.5 : 1)
                    .disabled(busy)
                    .lineLimit(2)
                    .onAppear { n = 1 }
                    .onTapGesture(count: 2) { n += 1 }
        """))
        try assertBody(payload, equals: #"""
        {"text": {"value": "Hi", "modifiers": [
          {"systemFont": {"font": "title"}}, {"fontWeight": {"weight": "semibold"}}, {"bold": {}},
          {"foregroundColor": {"color": "#80FF3B30"}}, {"padding": {}}, {"padding": {"edges": "horizontal", "length": 12}},
          {"frame": {"maxWidth": "infinity", "alignment": "leading"}},
          {"background": {"content": {"color": {"color": "#FFFF8000"}}}}, {"cornerRadius": {"radius": 8}},
          {"shadow": {"radius": 4, "y": 2}}, {"opacity": {"value": {"if": [{"var": "busy"}, 0.5, 1]}}},
          {"disabled": {"isDisabled": {"var": "busy"}}}, {"lineLimit": {"limit": 2}},
          {"onAppear": {"do": [{"set": "n", "to": 1}]}},
          {"onTapGesture": {"count": 2, "do": [{"set": "n", "to": {"add": [{"var": "n"}, 1]}}]}}
        ]}}
        """#)
    }

    // MARK: diagnostics

    func testUnsupportedViewsModifiersAndOptions() {
        XCTAssertEqual(diagnostics(screen("List { Text(\"a\") }")),
                       ["Screen.swift:6:9: error: 'List' isn't supported in v1 (supported: Text, Image, Label, Button, Color, shapes, Spacer, Divider, stacks, Group, Form, Section, ScrollView, NavigationStack)"])
        XCTAssertEqual(diagnostics(screen("Text(\"a\").navigationTitle(\"x\")")),
                       ["Screen.swift:6:19: error: Modifier '.navigationTitle' isn't supported in v1"])
        XCTAssertEqual(diagnostics(screen("Text(\"a\").font(.huge)")),
                       ["Screen.swift:6:24: error: '.huge' isn't a supported font"])
        XCTAssertEqual(diagnostics(screen("Text(\"a\").foregroundColor(.primary)")),
                       ["Screen.swift:6:35: error: Unsupported color '.primary': use a named color like .blue or Color(red:green:blue:)"])
    }

    func testReportsEveryErrorNotJustTheFirst() {
        let errors = diagnostics(screen(state: "@State var n = 0", """
        VStack {
                    Text(missing)
                    Toggle("x", isOn: .constant(true))
                    Text("ok").blink()
                }
        """))
        XCTAssertEqual(errors.count, 3, "\(errors)")
    }

    func testFileLevelErrors() {
        XCTAssertEqual(diagnostics("import SwiftUI\nstruct Model { var x = 1 }"),
                       ["Screen.swift:1:1: error: No `struct …: View` found to compile"])
        XCTAssertEqual(diagnostics(screen("Text(\"a\")") + "\nstruct Other: View { var body: some View { Text(\"b\") } }").last,
                       "Screen.swift:9:8: error: Only one View per file is supported in v1 (helper views come in v2): move 'Other' to its own file")
        XCTAssertEqual(diagnostics("struct Broken: View { var body: some View { Text(\"a\" } }").first?.contains("doesn't parse as Swift"), true)
    }

    func testOutputJSONIsStable() throws {
        let source = screen(state: "@State var n = 0", "Text(\"\\(n)\")")
        let first = try XCTUnwrap(try SwiftUICompiler.compile(source: source, version: "7").json())
        let second = try XCTUnwrap(try SwiftUICompiler.compile(source: source, version: "7").json())
        XCTAssertEqual(first, second)
        XCTAssertTrue(String(decoding: first, as: UTF8.self).contains(#""version" : "7""#))
    }
}
