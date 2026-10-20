//
//  TabInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct TabInsertable: View {
    let viewStore: TabViewStore

    private var tabs: some View {
        ForEach(Array(viewStore.children.enumerated()), id: \.offset) { index, child in
            InjectedContent(child).tag(index)
        }
    }

    private func indexBinding(_ scope: StateScope, _ path: String) -> Binding<Int> {
        let binding = scope.binding(path)
        return Binding(
            get: { Int(runtimeValue: binding.wrappedValue) ?? 0 },
            set: { binding.wrappedValue = .number(Double($0)) })
    }

    var body: some View {
        ScopeReader { scope in
            Group {
                if let selection = viewStore.selection {
                    TabView(selection: indexBinding(scope, selection)) { tabs }
                } else {
                    TabView { tabs }
                }
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
