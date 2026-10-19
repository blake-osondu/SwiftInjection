//
//  LazyHGridInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct LazyHGridInsertable: View {
    let viewStore: LazyHGridViewStore

    var body: some View {
        ScopeReader { scope in
            LazyHGrid(rows: viewStore.rows.map(\.render),
                      alignment: scope.resolve(viewStore.alignment, as: InjectedVerticalAlignment.self)?.render ?? .center,
                      spacing: scope.resolve(viewStore.spacing, as: CGFloat.self),
                      pinnedViews: viewStore.pinnedViews.render) {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
