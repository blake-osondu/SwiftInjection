//
//  GroupInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct GroupInsertable: View {
    let viewStore: GroupViewStore

    var body: some View {
        ScopeReader { scope in
            Group {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
