//
//  EllipseInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct EllipseInsertable: View {
    let viewStore: EllipseViewStore

    var body: some View {
        ScopeReader { scope in
            Ellipse()
                .applyShapeModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
