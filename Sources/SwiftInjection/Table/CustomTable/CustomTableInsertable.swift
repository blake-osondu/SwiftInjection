//
//  CustomTableInsertable.swift
//
//
//  Created by Blake Osonduagwueki on 10/9/23.
//

import Foundation
import SwiftUI

struct CustomTableInsertable: View {
    @ObservedObject var store: CustomTableStore
    var container: ViewStoresContainer

    var customTable: some View {
        Table(of: InjectedState.self) {
            TableColumn(store.viewStore.customTable?.viewStore1?.title ?? "") { (_: InjectedState) in
                Insertable(stateSignal: store.stateSignal, container: container, viewStore: store.viewStore.customTable?.viewStore1?.view ?? InjectedView.empty()).eraseToAnyView()
            }
            TableColumn(store.viewStore.customTable?.viewStore2?.title ?? "") { (_: InjectedState) in
                Insertable(stateSignal: store.stateSignal, container: container, viewStore: store.viewStore.customTable?.viewStore2?.view ?? InjectedView.empty()).eraseToAnyView()
            }
//            TableColumn(store.viewStore.customTable?.viewStore3?.title ?? "") { (_: InjectedState) in
//                (store.viewStore.customTable?.viewStore3?.view ?? EmptyViewStore()).insertable(stateSignal: store.stateSignal, container: container).eraseToAnyView()
//            }
//            TableColumn(store.viewStore.customTable?.viewStore4?.title ?? "") { (_: InjectedState) in
//                Insertable(state: .init(state), container: container, viewStore: store.viewStore.customTable?.viewStore4?.view ?? EmptyViewStore())
//            }
//            TableColumn(store.viewStore.customTable?.viewStore5?.title ?? "") { (_: InjectedState) in
//                Insertable(state: .init(state), container: container, viewStore: store.viewStore.customTable?.viewStore5?.view ?? EmptyViewStore())
//            }
        } rows: {
            TableRow(store.viewStore.customTable?.viewStore1?.state ?? InjectedState.empty)
            TableRow(store.viewStore.customTable?.viewStore2?.state ?? InjectedState.empty)
//            TableRow(store.viewStore.customTable?.viewStore3?.state ?? InjectedState.empty)
//            TableRow(store.viewStore.customTable?.viewStore4?.state ?? InjectedState.empty)
//            TableRow(store.viewStore.customTable?.viewStore5?.state ?? InjectedState.empty)
        }.addModifiers(mods: store.viewStore.modifiers, stateSignal: store.stateSignal, container: container)
    }
    var body: some View {
       EmptyView()
    }
}

