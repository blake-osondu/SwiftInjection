//
//  ForEachInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ForEachInsertable: View {
    let viewStore: ForEachViewStore

    var body: some View {
        ScopeReader { scope in
            InjectedRows(scope: scope, items: viewStore.items, itemName: viewStore.itemName,
                         identity: viewStore.identity, content: viewStore.content)
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}

/// One `content` per element of the array at `items`, each rendered with its item scope.
struct InjectedRows: View {
    let scope: StateScope
    let items: String
    let itemName: String?
    let identity: InjectedExpression?
    let content: InjectedView

    struct Row: Identifiable {
        let id: RuntimeValue
        let scope: StateScope
    }

    var rows: [Row] {
        scope.items(at: items).indices.map { index in
            let itemScope = scope.itemScope(items, index: index, name: itemName ?? "item")
            let id = identity.flatMap { itemScope.evaluate($0) } ?? .number(Double(index))
            return Row(id: id, scope: itemScope)
        }
    }

    var body: some View {
        ForEach(rows) { row in
            InjectedContent(content)
                .scopeLocals(row.scope.locals)
        }
    }
}
