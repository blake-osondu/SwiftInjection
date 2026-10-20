//
//  RectangleInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct RectangleInsertable: View {
    let viewStore: RectangleViewStore

    var body: some View {
        ScopeReader { scope in
            Rectangle()
                .applyShapeModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
