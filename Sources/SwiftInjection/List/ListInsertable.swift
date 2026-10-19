//
//  ListInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct ListInsertable: View {
    let viewStore: ListViewStore

    var body: some View {
        ScopeReader { scope in
            List {
                InjectedChildren(viewStore.children)
                if let items = viewStore.items, let content = viewStore.content {
                    InjectedRows(scope: scope, items: items, itemName: viewStore.itemName,
                                 identity: viewStore.identity, content: content)
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
