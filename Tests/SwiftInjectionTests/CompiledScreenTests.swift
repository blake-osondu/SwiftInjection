import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection
@testable import SwiftInjectionCore
import SwiftInjectionCompiler

/// Compiles real SwiftUI source with the compiler, then renders and drives the output with the runtime.
final class CompiledScreenTests: XCTestCase {

    private func compiledScreen(_ source: String, scripts: String? = nil) throws -> (InjectedScreen, StateStore) {
        let result = SwiftUICompiler.compile(source: source, fileName: "TodoScreen.swift", scripts: scripts)
        XCTAssertEqual(result.diagnostics.map(\.description), [])
        // Go through JSON, exactly as a published payload would.
        let json = try XCTUnwrap(try result.json())
        let payload = try PayloadValidator().validate(json, signature: nil).payload
        let store = StateStore(payload: payload)
        return (InjectedScreen(store: store, payload: payload), store)
    }

    func testCompiledTodoScreenBehaves() throws {
        let source = """
        import SwiftUI

        struct Todo: Identifiable {
            var id = UUID()
            var title: String
            var done = false
        }

        struct TodoScreen: View {
            @State private var count = 0
            @State private var todos = [Todo(title: "Milk"), Todo(title: "Eggs")]

            var body: some View {
                VStack {
                    Text("Tapped \\(count) times")
                    Button("Tap") { count += 1 }
                    if count >= 3 {
                        Text("Three!")
                    }
                    ForEach($todos) { $todo in
                        HStack {
                            TextField("To-do", text: $todo.title)
                            Button(todo.done ? "Undo" : "Done") { todo.done.toggle() }
                        }
                    }
                    Footer(count: todos.count)
                }
            }
        }

        struct Footer: View {
            let count: Int
            var body: some View { Text("\\(count) to-dos") }
        }
        """
        let (screen, store) = try compiledScreen(source)
        func texts() throws -> [String] { try screen.inspect().findAll(ViewType.Text.self).map { try $0.string() } }

        XCTAssertTrue(try texts().contains("Tapped 0 times"))
        XCTAssertTrue(try texts().contains("2 to-dos"))
        for _ in 0..<3 { try screen.inspect().find(button: "Tap").tap() }
        XCTAssertTrue(try texts().contains("Tapped 3 times"))
        XCTAssertTrue(try texts().contains("Three!"))

        let fields = try screen.inspect().findAll(ViewType.TextField.self)
        try fields[1].setInput("Free-range eggs")
        try screen.inspect().findAll(ViewType.Button.self).first { (try? $0.labelView().text().string()) == "Done" }?.tap()

        XCTAssertEqual(store.value(at: ["todos", "1", "title"]), "Free-range eggs")
        XCTAssertEqual(store.value(at: ["todos", "0", "done"]), true)
        XCTAssertEqual(store.value(at: ["todos", "1", "done"]), false)
    }

    func testCompiledScriptsRun() throws {
        let source = """
        import SwiftUI
        import SwiftInjectionAuthoring

        struct TodoScreen: View {
            @State private var price = 4.5
            @State private var todos: [String] = []

            var body: some View {
                VStack {
                    Text(script("formatPrice", price))
                    Button("Add") { runScript("addTodo", "Milk") }
                    Text("\\(todos.count) to-dos")
                }
            }
        }
        """
        let scripts = """
        function formatPrice(amount) { return currency() + amount.toFixed(2) }
        function currency() { return "$" }
        const addTodo = (title) => { state.set("todos", state.get("todos").concat([title])) }
        """
        let (screen, store) = try compiledScreen(source, scripts: scripts)
        XCTAssertNoThrow(try screen.inspect().find(text: "$4.50"))  // a helper function in the same file works
        try screen.inspect().find(button: "Add").tap()
        XCTAssertEqual(store.value(at: ["todos"]), ["Milk"])
        XCTAssertNoThrow(try screen.inspect().find(text: "1 to-dos"))
    }
}
