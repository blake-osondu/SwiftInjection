//
//  IfInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct IfInsertable: View {
    let viewStore: IfViewStore

    var body: some View {
        ScopeReader { scope in
            Group {
                if scope.bool(viewStore.condition) {
                    InjectedContent(viewStore.then)
                } else if let otherwise = viewStore.otherwise {
                    InjectedContent(otherwise)
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
