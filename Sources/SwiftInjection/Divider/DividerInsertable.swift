//
//  DividerInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct DividerInsertable: View {
    let viewStore: DividerViewStore

    var body: some View {
        ScopeReader { scope in
            Divider()
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
