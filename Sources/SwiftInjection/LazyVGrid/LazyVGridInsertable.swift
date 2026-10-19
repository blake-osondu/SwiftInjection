//
//  LazyVGridInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct LazyVGridInsertable: View {
    let viewStore: LazyVGridViewStore

    var body: some View {
        ScopeReader { scope in
            LazyVGrid(columns: viewStore.columns.map(\.render),
                      alignment: scope.resolve(viewStore.alignment, as: InjectedHorizontalAlignment.self)?.render ?? .center,
                      spacing: scope.resolve(viewStore.spacing, as: CGFloat.self),
                      pinnedViews: viewStore.pinnedViews.render) {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
