//
//  TextInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct TextInsertable: View {
    let viewStore: TextViewStore

    var body: some View {
        ScopeReader { scope in
            Text(scope.string(viewStore.value))
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
