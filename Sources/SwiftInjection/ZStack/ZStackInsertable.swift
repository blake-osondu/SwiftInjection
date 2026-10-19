//
//  ZStackInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct ZStackInsertable: View {
    let viewStore: ZStackViewStore

    var body: some View {
        ScopeReader { scope in
            ZStack(alignment: scope.resolve(viewStore.alignment, as: InjectedAlignment.self)?.render ?? .center) {
                InjectedChildren(viewStore.children)
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
