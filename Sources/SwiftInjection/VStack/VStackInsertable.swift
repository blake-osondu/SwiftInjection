//
//  VStackInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct VStackInsertable: View {
    let viewStore: VStackViewStore
    var lazy = false

    var body: some View {
        ScopeReader { scope in
            Group {
                let alignment = scope.resolve(viewStore.alignment, as: InjectedHorizontalAlignment.self)?.render ?? .center
                let spacing = scope.resolve(viewStore.spacing, as: CGFloat.self)
                if lazy {
                    LazyVStack(alignment: alignment, spacing: spacing, pinnedViews: viewStore.pinnedViews.render) {
                        InjectedChildren(viewStore.children)
                    }
                } else {
                    VStack(alignment: alignment, spacing: spacing) {
                        InjectedChildren(viewStore.children)
                    }
                }
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
