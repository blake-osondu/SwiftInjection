//
//  CapsuleInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct CapsuleInsertable: View {
    let viewStore: CapsuleViewStore

    var body: some View {
        ScopeReader { scope in
            Capsule(style: scope.resolve(viewStore.style, as: InjectedRoundedCornerStyle.self)?.render ?? .continuous)
                .applyShapeModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
