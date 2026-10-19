//
//  CircleInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct CircleInsertable: View {
    let viewStore: CircleViewStore

    var body: some View {
        ScopeReader { scope in
            Circle()
                .applyShapeModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
