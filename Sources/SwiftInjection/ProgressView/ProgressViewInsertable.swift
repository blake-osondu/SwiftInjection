//
//  ProgressViewInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct ProgressViewInsertable: View {
    let viewStore: ProgressViewStore

    var body: some View {
        ScopeReader { scope in
            Group {
                if let start = scope.resolve(viewStore.timerStart, as: Date.self),
                   let end = scope.resolve(viewStore.timerEnd, as: Date.self), start <= end {
                    ProgressView(timerInterval: start...end, countsDown: scope.resolve(viewStore.countsDown, as: Bool.self) ?? true) {
                        label(scope)
                    } currentValueLabel: {
                        currentValueLabel
                    }
                } else if let value = scope.resolve(viewStore.value, as: Double.self) {
                    ProgressView(value: value, total: scope.resolve(viewStore.total, as: Double.self) ?? 1) {
                        label(scope)
                    } currentValueLabel: {
                        currentValueLabel
                    }
                } else {
                    ProgressView {
                        label(scope)
                    }
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }

    @ViewBuilder private func label(_ scope: StateScope) -> some View {
        if let label = viewStore.label {
            InjectedContent(label)
        } else if let title = viewStore.title {
            Text(scope.string(title))
        }
    }

    @ViewBuilder private var currentValueLabel: some View {
        if let currentValueLabel = viewStore.currentValueLabel {
            InjectedContent(currentValueLabel)
        }
    }
}
