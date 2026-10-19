//
//  NavigationLinkInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct NavigationLinkInsertable: View {
    let viewStore: NavigationLinkViewStore

    var body: some View {
        ScopeReader { scope in
            NavigationLink {
                InjectedContent(viewStore.destination)
            } label: {
                InjectedContent(viewStore.label)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
