//
//  TextFieldInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct TextFieldInsertable: View {
    let viewStore: FieldViewStore

    var body: some View {
        ScopeReader { scope in
            TextField(scope.string(viewStore.title),
                      text: scope.stringBinding(viewStore.text),
                      prompt: viewStore.prompt.map { Text(scope.string($0)) })
                .onSubmit { scope.perform(viewStore.onSubmit) }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
