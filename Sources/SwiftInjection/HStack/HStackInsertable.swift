//
//  HStackInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct HStackInsertable: View {
    let viewStore: HStackViewStore
    var lazy = false

    var body: some View {
        ScopeReader { scope in
            Group {
                let alignment = scope.resolve(viewStore.alignment, as: InjectedVerticalAlignment.self)?.render ?? .center
                let spacing = scope.resolve(viewStore.spacing, as: CGFloat.self)
                if lazy {
                    LazyHStack(alignment: alignment, spacing: spacing, pinnedViews: viewStore.pinnedViews.render) {
                        InjectedChildren(viewStore.children)
                    }
                } else {
                    HStack(alignment: alignment, spacing: spacing) {
                        InjectedChildren(viewStore.children)
                    }
                }
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
