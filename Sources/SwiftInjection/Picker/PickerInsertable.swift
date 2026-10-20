//
//  PickerInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct PickerInsertable: View {
    let viewStore: PickerViewStore

    var body: some View {
        ScopeReader { scope in
            Picker(selection: scope.binding(viewStore.selection)) {
                ForEach(Array(scope.items(at: viewStore.items).enumerated()), id: \.offset) { index, _ in
                    let itemScope = scope.itemScope(viewStore.items, index: index, name: viewStore.itemName ?? "item")
                    Group {
                        if let content = viewStore.content {
                            InjectedContent(content)
                        } else {
                            Text(itemScope.string(.var(viewStore.itemName ?? "item")))
                        }
                    }
                    .tag(itemScope.evaluate(viewStore.value ?? .var(viewStore.itemName ?? "item")) ?? .null)
                    .scopeLocals(itemScope.locals)
                }
            } label: {
                if let label = viewStore.label {
                    InjectedContent(label)
                } else {
                    Text(scope.string(viewStore.title))
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
