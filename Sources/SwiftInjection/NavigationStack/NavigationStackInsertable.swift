//
//  NavigationStackInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct NavigationStackInsertable: View {
    let viewStore: NavigationStackViewStore

    var body: some View {
        ScopeReader { scope in
            NavigationStack {
                InjectedContent(viewStore.root)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
