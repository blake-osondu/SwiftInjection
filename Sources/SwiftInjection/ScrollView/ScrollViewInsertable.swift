//
//  ScrollViewInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ScrollViewInsertable: View {
    let viewStore: ScrollViewStore

    var body: some View {
        ScopeReader { scope in
            ScrollView((viewStore.axes ?? .vertical).render, showsIndicators: scope.resolve(viewStore.showsIndicators, as: Bool.self) ?? true) {
                if viewStore.axes == .horizontal {
                    HStack { InjectedChildren(viewStore.children) }
                } else {
                    VStack { InjectedChildren(viewStore.children) }
                }
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
