//
//  LabelInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct LabelInsertable: View {
    let viewStore: LabelViewStore

    var body: some View {
        ScopeReader { scope in
            Label {
                if let titleView = viewStore.titleView {
                    InjectedContent(titleView)
                } else {
                    Text(scope.string(viewStore.title))
                }
            } icon: {
                if let iconView = viewStore.iconView {
                    InjectedContent(iconView)
                } else if let systemImage = scope.resolve(viewStore.systemImage, as: String.self) {
                    Image(systemName: systemImage)
                } else if let image = scope.resolve(viewStore.image, as: String.self) {
                    Image(image)
                }
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
