//
//  SecureFieldInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct SecureFieldInsertable: View {
    let viewStore: SecureFieldViewStore

    var body: some View {
        ScopeReader { scope in
            SecureField(scope.string(viewStore.title),
                      text: scope.stringBinding(viewStore.text),
                      prompt: viewStore.prompt.map { Text(scope.string($0)) })
                .onSubmit { scope.perform(viewStore.onSubmit) }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
