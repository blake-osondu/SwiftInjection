//
//  TableInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct TableInsertable: View {
    let viewStore: TableViewStore

    private struct Row: Identifiable {
        let id: Int
        let scope: StateScope
    }

    private struct Column: Identifiable {
        let id: Int
        let column: InjectedTableColumn
    }

    var body: some View {
        ScopeReader { scope in
            let rows = scope.items(at: viewStore.items).indices.map {
                Row(id: $0, scope: scope.itemScope(viewStore.items, index: $0, name: viewStore.itemName ?? "item"))
            }
            Group {
                if #available(iOS 17.4, *) {
                    let columns = viewStore.columns.enumerated().map { Column(id: $0.offset, column: $0.element) }
                    Table(rows) {
                        TableColumnForEach(columns) { column in
                            TableColumn(scope.string(column.column.title)) { (row: Row) in
                                InjectedContent(column.column.content).scopeLocals(row.scope.locals)
                            }
                        }
                    }
                } else if let first = viewStore.columns.first {
                    List(rows) { row in
                        InjectedContent(first.content).scopeLocals(row.scope.locals)
                    }
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
