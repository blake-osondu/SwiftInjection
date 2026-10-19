//
//  FormInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct FormInsertable: View {
    let viewStore: FormViewStore

    var body: some View {
        ScopeReader { scope in
            Form {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
