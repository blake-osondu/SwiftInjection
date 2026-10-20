//
//  SectionInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct SectionInsertable: View {
    let viewStore: SectionViewStore

    var body: some View {
        ScopeReader { scope in
            Section {
                InjectedChildren(viewStore.children)
            } header: {
                if let header = viewStore.header {
                    InjectedContent(header)
                } else if let title = viewStore.title {
                    Text(scope.string(title))
                }
            } footer: {
                if let footer = viewStore.footer {
                    InjectedContent(footer)
                }
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
