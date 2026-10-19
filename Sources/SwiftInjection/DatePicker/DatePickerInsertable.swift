//
//  DatePickerInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct DatePickerInsertable: View {
    let viewStore: DatePickerViewStore

    var body: some View {
        ScopeReader { scope in
            let range = (scope.resolve(viewStore.minimum, as: Date.self) ?? .distantPast)...(scope.resolve(viewStore.maximum, as: Date.self) ?? .distantFuture)
            DatePicker(selection: scope.dateBinding(viewStore.selection), in: range,
                       displayedComponents: (viewStore.components ?? [.date, .hourAndMinute]).render) {
                if let label = viewStore.label {
                    InjectedContent(label)
                } else {
                    Text(scope.string(viewStore.title))
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
