//
//  GridInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct GridInsertable: View {
    let viewStore: GridViewStore

    var body: some View {
        ScopeReader { scope in
            Grid(alignment: scope.resolve(viewStore.alignment, as: InjectedAlignment.self)?.render ?? .center,
                 horizontalSpacing: scope.resolve(viewStore.horizontalSpacing, as: CGFloat.self),
                 verticalSpacing: scope.resolve(viewStore.verticalSpacing, as: CGFloat.self)) {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
