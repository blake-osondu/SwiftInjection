//
//  RoundedRectangleInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct RoundedRectangleInsertable: View {
    let viewStore: RoundedRectangleViewStore

    var body: some View {
        ScopeReader { scope in
            RoundedRectangle(
                cornerSize: CGSize(
                    width: scope.resolve(viewStore.cornerWidth ?? viewStore.cornerRadius, as: CGFloat.self) ?? 0,
                    height: scope.resolve(viewStore.cornerHeight ?? viewStore.cornerRadius, as: CGFloat.self) ?? 0),
                style: scope.resolve(viewStore.style, as: InjectedRoundedCornerStyle.self)?.render ?? .continuous)
                .applyShapeModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
