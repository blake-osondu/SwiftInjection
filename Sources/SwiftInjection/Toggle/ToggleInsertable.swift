//
//  ToggleInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ToggleInsertable: View {
    let viewStore: ToggleViewStore

    var body: some View {
        ScopeReader { scope in
            Toggle(isOn: scope.boolBinding(viewStore.isOn)) {
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
