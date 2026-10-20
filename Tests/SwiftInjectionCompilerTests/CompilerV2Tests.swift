import XCTest
@testable import SwiftInjectionCompiler
@testable import SwiftInjectionCore

final class CompilerV2Tests: XCTestCase {

    private func compile(_ source: String, scripts: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws -> InjectedPayload {
        let result = SwiftUICompiler.compile(source: source, fileName: "Screen.swift", scripts: scripts)
        XCTAssertEqual(result.diagnostics.map(\.description), [], file: file, line: line)
        return try XCTUnwrap(result.payload, file: file, line: line)
    }

    private func diagnostics(_ source: String, scripts: String? = nil) -> [String] {
        SwiftUICompiler.compile(source: source, fileName: "Screen.swift", scripts: scripts).diagnostics.map(\.description)
    }

    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func assertBody(_ payload: InjectedPayload, equals expected: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expectedView = try JSONDecoder().decode(InjectedView.self, from: Data(expected.utf8))
        XCTAssertEqual(try json(payload.body), try json(expectedView), file: file, line: line)
    }

    private func screen(state: String = "", _ body: String, extra: String = "") -> String {
        """
        import SwiftUI

        \(extra)
        struct Screen: View {
            \(state)
            var body: some View {
                \(body)
            }
        }
        """
    }

    // MARK: acceptance: the full end-to-end screen

    static let todoScreen = """
    import SwiftUI

    struct Todo: Identifiable {
        var id = UUID()
        var title: String
        var done = false
    }

    struct TodoScreen: View {
        @State private var count = 0
        @State private var todos = [Todo(title: "Milk")]

        var body: some View {
            VStack {
                Text("Tapped \\(count) times")
                Button("Tap") { count += 1 }
                if count >= 10 {
                    Text("Double digits!")
                }
                ForEach($todos) { $todo in
                    TextField("To-do", text: $todo.title)
                }
                Footer()
                TodoCount(count: todos.count)
            }
        }
    }

    struct Footer: View {
        var body: some View {
            Text("Made with SwiftInjection")
        }
    }

    struct TodoCount: View {
        let count: Int

        var body: some View {
            Text("\\(count) to-do(s)")
        }
    }
    """

    func testFullScreenCompilesToTheHandWrittenPayload() throws {
        let expected = #"""
        {
          "schemaVersion": "1.0",
          "state": { "count": 0, "todos": [ { "id": "Todo-1", "title": "Milk", "done": false } ] },
          "body": { "vStack": { "children": [
            { "text": { "value": { "format": ["Tapped {0} times", { "var": "count" }] } } },
            { "button": { "title": "Tap", "action": [ { "set": "count", "to": { "add": [{ "var": "count" }, 1] } } ] } },
            { "if": { "condition": { "gte": [{ "var": "count" }, 10] }, "then": { "text": { "value": "Double digits!" } } } },
            { "forEach": { "items": "todos", "itemName": "todo", "identity": { "var": "todo.id" },
                           "content": { "field": { "text": "todo.title", "title": "To-do" } } } },
            { "ref": "Footer" },
            { "text": { "value": { "format": ["{0} to-do(s)", { "count": { "var": "todos" } }] } } }
          ]}},
          "views": { "Footer": { "text": { "value": "Made with SwiftInjection" } } }
        }
        """#
        let compiled = try compile(Self.todoScreen)
        let handWritten = try JSONDecoder().decode(InjectedPayload.self, from: Data(expected.utf8))
        XCTAssertEqual(try json(compiled), try json(handWritten))
    }

    // MARK: data

    func testForEachAndListForms() throws {
        let payload = try compile(screen(state: "@State var names = [\"a\", \"b\"]\n    @State var todos = [Todo(title: \"x\")]", """
        VStack {
                    ForEach(names, id: \\.self) { name in Text(name) }
                    List(todos) { todo in
                        Button(todo.title) { todo.done.toggle() }
                            .opacity(todo.done ? 0.5 : 1)
                    }
                    List {
                        Text("Static")
                        ForEach(todos, id: \\.title) { todo in Text(todo.title) }
                    }
                }
        """, extra: "struct Todo { var title: String\n    var done = false }"))
        try assertBody(payload, equals: #"""
        {"vStack": {"children": [
          {"forEach": {"items": "names", "itemName": "name", "identity": {"var": "name"}, "content": {"text": {"value": {"var": "name"}}}}},
          {"list": {"items": "todos", "itemName": "todo", "content": {"button": {"title": {"var": "todo.title"},
             "action": [{"set": "todo.done", "to": {"not": {"var": "todo.done"}}}],
             "modifiers": [{"opacity": {"value": {"if": [{"var": "todo.done"}, 0.5, 1]}}}]}}}},
          {"list": {"children": [{"text": {"value": "Static"}},
            {"forEach": {"items": "todos", "itemName": "todo", "identity": {"var": "todo.title"}, "content": {"text": {"value": {"var": "todo.title"}}}}}]}}
        ]}}
        """#)
    }

    func testDataDiagnostics() {
        XCTAssertEqual(diagnostics(screen(state: "@State var n = [1]", "ForEach(n) { Text(\"\\($0)\") }")),
                       ["Screen.swift:7:20: error: Name the closure's parameter, e.g. { todo in … } ($0 isn't supported)"])
        XCTAssertEqual(diagnostics(screen("ForEach(0..<3) { i in Text(\"x\") }")),
                       ["Screen.swift:7:17: error: ForEach/List can iterate @State arrays and their fields (not ranges or computed values)"])
        XCTAssertEqual(diagnostics(screen(state: "@State var t = \"\"", "Text($t)")),
                       ["Screen.swift:7:14: error: '$t' is a binding; bindings can only be passed where SwiftUI expects one (text:, isOn:, selection:, …)"])
    }

    // MARK: inputs

    func testInputs() throws {
        let payload = try compile(screen(state: """
        @State var name = ""
            @State var password = ""
            @State var notify = true
            @State var size = "m"
            @State var sizes = ["s", "m", "l"]
            @State var flavor = 0
            @State var due = Date()
            @State var progress = 0.5
        """, """
        Form {
                    TextField("Name", text: $name, prompt: Text("Ada Lovelace"))
                    SecureField("Password", text: $password)
                    Toggle("Notifications", isOn: $notify)
                    Picker("Size", selection: $size) {
                        ForEach(sizes, id: \\.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    Picker("Flavor", selection: $flavor) {
                        Text("Vanilla").tag(0)
                        Text("Chocolate").tag(1)
                    }
                    DatePicker("Due", selection: $due, displayedComponents: .date)
                    ProgressView("Uploading", value: progress, total: 1)
                }
        """))
        XCTAssertEqual(payload.state.value(at: ["__options0"]), [["label": "Vanilla", "value": 0], ["label": "Chocolate", "value": 1]])
        XCTAssertEqual(payload.state.value(at: ["due"]), .null)  // "now" until the user picks a date
        try assertBody(payload, equals: #"""
        {"form": {"children": [
          {"field": {"text": "name", "title": "Name", "prompt": "Ada Lovelace"}},
          {"secureField": {"text": "password", "title": "Password"}},
          {"toggle": {"isOn": "notify", "title": "Notifications"}},
          {"picker": {"selection": "size", "items": "sizes", "itemName": "size", "title": "Size",
                      "content": {"text": {"value": {"var": "size"}}}, "value": {"var": "size"}}},
          {"picker": {"selection": "flavor", "items": "__options0", "itemName": "option", "title": "Flavor",
                      "content": {"text": {"value": {"var": "option.label"}}}, "value": {"var": "option.value"}}},
          {"datePicker": {"selection": "due", "title": "Due", "components": ["date"]}},
          {"progressView": {"title": "Uploading", "value": {"var": "progress"}, "total": 1}}
        ]}}
        """#)
    }

    // MARK: presentation and events

    func testPresentationAndEvents() throws {
        let payload = try compile(screen(state: "@State var showing = false\n    @State var confirming = false\n    @State var query = \"\"\n    @State var searches = 0", """
        NavigationStack {
                    TextField("Search", text: $query)
                        .onSubmit { searches += 1 }
                        .onChange(of: query) { oldValue, newValue in searches += 1 }
                        .navigationTitle("Search")
                        .sheet(isPresented: $showing) { Text("Sheet") }
                        .alert("Delete?", isPresented: $confirming) {
                            Button("Delete", role: .destructive) { query = "" }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This can't be undone.")
                        }
                        .confirmationDialog("Share", isPresented: $showing, titleVisibility: .visible) {
                            Button("Copy") { searches = 0 }
                        }
                }
        """))
        try assertBody(payload, equals: #"""
        {"navigationStack": {"root": {"field": {"text": "query", "title": "Search", "modifiers": [
          {"onSubmit": {"do": [{"set": "searches", "to": {"add": [{"var": "searches"}, 1]}}]}},
          {"onChange": {"of": {"var": "query"}, "do": [{"set": "searches", "to": {"add": [{"var": "searches"}, 1]}}]}},
          {"navigationTitle": {"title": "Search"}},
          {"sheet": {"isPresented": "showing", "content": {"text": {"value": "Sheet"}}}},
          {"alert": {"isPresented": "confirming", "alert": {"title": "Delete?", "message": "This can't be undone.", "buttons": [
            {"label": "Delete", "role": "destructive", "action": [{"set": "query", "to": ""}]},
            {"label": "Cancel", "role": "cancel"}]}}},
          {"confirmationDialog": {"isPresented": "showing", "title": "Share", "titleVisibility": "visible",
            "actions": {"button": {"title": "Copy", "action": [{"set": "searches", "to": 0}]}}}}
        ]}}}}
        """#)
    }

    // MARK: helper views

    func testHelperViewsWithValuesBindingsAndDefaults() throws {
        let payload = try compile(screen(state: "@State var notify = true\n    @State var name = \"Ada\"", """
        VStack {
                    SettingRow(title: "Notifications", isOn: $notify)
                    Greeting(name: name)
                    Greeting(name: "Bob", punctuation: "?")
                }
        """, extra: """
        struct SettingRow: View {
            let title: String
            @Binding var isOn: Bool
            var body: some View {
                Toggle(title, isOn: $isOn)
                    .bold(isOn)
            }
        }
        struct Greeting: View {
            let name: String
            var punctuation = "!"
            var body: some View { Text("Hi \\(name)\\(punctuation)") }
        }
        """))
        try assertBody(payload, equals: #"""
        {"vStack": {"children": [
          {"toggle": {"isOn": "notify", "title": "Notifications", "modifiers": [{"bold": {"isActive": {"var": "notify"}}}]}},
          {"text": {"value": {"format": ["Hi {0}{1}", {"var": "name"}, "!"]}}},
          {"text": {"value": {"format": ["Hi {0}{1}", "Bob", "?"]}}}
        ]}}
        """#)
        XCTAssertTrue(payload.views.isEmpty)
    }

    func testHelperViewDiagnostics() {
        XCTAssertEqual(diagnostics(screen("Loop()", extra: "struct Loop: View { var body: some View { Loop() } }")).first,
                       "Screen.swift:3:43: error: 'Loop' uses itself; recursive views aren't supported")
        XCTAssertEqual(diagnostics(screen("Counter()", extra: "struct Counter: View { var body: some View { Text(\"x\") }\n    @State var n = 0 }")).first?.hasSuffix("Helper views can't have @State; keep state in the screen and pass it in (with @Binding to change it)"), true)
        XCTAssertEqual(diagnostics(screen("Row()", extra: "struct Row: View { let title: String\n    var body: some View { Text(title) } }")),
                       ["Screen.swift:8:9: error: Missing argument 'title' for 'Row'"])
    }

    // MARK: scripts

    static let scripts = """
    function formatPrice(amount) { return "$" + amount.toFixed(2) }
    const addTodo = (title) => { state.set("todos", state.get("todos").concat([{ title }])) }
    """

    func testScriptsBecomeCallsWithTheirSource() throws {
        let payload = try compile(screen(state: "@State var price = 4.5\n    @State var todos: [String] = []", """
        VStack {
                    Text(script("formatPrice", price))
                    Button("Add") { runScript("addTodo", "Milk") }
                        .opacity(script("fade", placeholder: 1.0))
                }
        """, extra: "import SwiftInjectionAuthoring"), scripts: Self.scripts + "\nfunction fade() { return 0.5 }")
        try assertBody(payload, equals: #"""
        {"vStack": {"children": [
          {"text": {"value": {"call": ["formatPrice", {"var": "price"}]}}},
          {"button": {"title": "Add", "action": [{"call": "addTodo", "args": ["Milk"]}], "modifiers": [{"opacity": {"value": {"call": ["fade"]}}}]}}
        ]}}
        """#)
        XCTAssertEqual(payload.scripts.keys.sorted(), ["addTodo", "fade", "formatPrice"])
        XCTAssertTrue(payload.scripts["formatPrice"]!.hasSuffix("return formatPrice;\n})()"))
    }

    func testScriptDiagnostics() {
        let source = screen("Text(script(\"missing\"))", extra: "import SwiftInjectionAuthoring")
        XCTAssertEqual(diagnostics(source).first?.contains("no script file was given"), true)
        XCTAssertEqual(diagnostics(source, scripts: Self.scripts).first?.contains("Script 'missing' isn't defined in the script file"), true)
        XCTAssertEqual(diagnostics(screen(state: "@State var n = \"x\"", "Text(script(n))", extra: "")).first?.contains("must be the function name as a string literal"), true)
    }

    func testNavigationLinks() throws {
        let payload = try compile(screen("""
        NavigationStack {
                    VStack {
                        NavigationLink("Settings") { Text("Settings screen") }
                        NavigationLink { Text("Profile screen") } label: { Label("Profile", systemImage: "person") }
                    }
                }
        """))
        try assertBody(payload, equals: #"""
        {"navigationStack": {"root": {"vStack": {"children": [
          {"navigationLink": {"label": {"text": {"value": "Settings"}}, "destination": {"text": {"value": "Settings screen"}}}},
          {"navigationLink": {"label": {"label": {"title": "Profile", "systemImage": "person"}}, "destination": {"text": {"value": "Profile screen"}}}}
        ]}}}}
        """#)
    }

    func testConditionalColors() throws {
        let payload = try compile(screen(state: "@State var done = false", "Text(\"x\").foregroundColor(done ? .green : (.gray))"))
        try assertBody(payload, equals: #"""
        {"text": {"value": "x", "modifiers": [{"foregroundColor": {"color": {"if": [{"var": "done"}, "#FF34C759", "#FF8E8E93"]}}}]}}
        """#)
    }

    func testHostFunctionsNeedNoScriptFile() throws {
        let result = SwiftUICompiler.compile(source: screen(state: "@State var id = \"a\"", """
        VStack {
                    if hostValue("featureEnabled", "offers", placeholder: false) {
                        Button("Open") { hostAction("navigate", "offers/" + id) }
                    }
                }
        """, extra: "import SwiftInjectionAuthoring"), fileName: "Screen.swift")
        XCTAssertEqual(result.diagnostics.map(\.description), [])
        XCTAssertEqual(result.hostFunctions, ["featureEnabled", "navigate"])
        let payload = try XCTUnwrap(result.payload)
        XCTAssertTrue(payload.scripts.isEmpty)
        try assertBody(payload, equals: #"""
        {"vStack": {"children": [{"if": {"condition": {"call": ["featureEnabled", "offers"]},
          "then": {"button": {"title": "Open", "action": [{"call": "navigate", "args": [{"concat": ["offers/", {"var": "id"}]}]}]}}}}]}}
        """#)
    }
}
