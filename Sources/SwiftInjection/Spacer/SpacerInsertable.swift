//
//  SpacerInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct SpacerInsertable: View {
    let viewStore: SpacerViewStore

    var body: some View {
        ScopeReader { scope in
            Spacer(minLength: scope.resolve(viewStore.minLength, as: CGFloat.self))
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
