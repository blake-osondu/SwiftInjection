//
//  ButtonInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ButtonInsertable: View {
    let viewStore: ButtonViewStore

    var body: some View {
        ScopeReader { scope in
            Button(role: viewStore.role?.render) {
                scope.perform(viewStore.action)
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
