//
//  GridRowInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct GridRowInsertable: View {
    let viewStore: GridRowViewStore

    var body: some View {
        ScopeReader { scope in
            GridRow(alignment: scope.resolve(viewStore.alignment, as: InjectedVerticalAlignment.self)?.render) {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
