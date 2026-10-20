import SwiftUI

// Compiled by `swift-injection compile`; also builds as ordinary SwiftUI, so Previews work if you add it to a target.

struct Todo: Identifiable {
    var id = UUID()
    var title: String
    var done = false
}

struct TodoScreen: View {
    @State private var todos = [Todo(title: "Try SwiftInjection"), Todo(title: "Edit TodoScreen.swift"), Todo(title: "Tap Reload")]
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List($todos) { $todo in
                TodoRow(todo: $todo)
            }
            .navigationTitle("To-dos")
            .sheet(isPresented: $showingAbout) {
                Text("This screen was downloaded, not built into the app.")
                    .padding()
            }
            Button("About this screen") { showingAbout = true }
                .padding()
        }
    }
}

struct TodoRow: View {
    @Binding var todo: Todo

    var body: some View {
        HStack {
            Button { todo.done.toggle() } label: {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.done ? .green : .gray)
            }
            .buttonStyle(.borderless)
            TextField("To-do", text: $todo.title)
                .strikethrough(todo.done)
        }
    }
}
