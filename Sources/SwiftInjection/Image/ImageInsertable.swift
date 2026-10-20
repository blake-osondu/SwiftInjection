//
//  ImageInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ImageInsertable: View {
    let viewStore: ImageViewStore

    var body: some View {
        ScopeReader { scope in
            if let url = scope.resolve(viewStore.url, as: String.self) {
                AsyncImage(url: URL(string: url), scale: scope.resolve(viewStore.scale, as: CGFloat.self) ?? 1) { image in
                    styled(image, scope)
                } placeholder: {
                    if let placeholder = viewStore.placeholder {
                        InjectedContent(placeholder)
                    } else {
                        ProgressView()
                    }
                }
            } else if let systemName = scope.resolve(viewStore.systemName, as: String.self) {
                styled(Image(systemName: systemName), scope)
            } else if let name = scope.resolve(viewStore.name, as: String.self) {
                styled(Image(name), scope)
            } else {
                styled(Image(systemName: "photo"), scope)
            }
        }
    }

    private func styled(_ image: Image, _ scope: StateScope) -> some View {
        image
            .applyImageModifiers(viewStore.modifiers, scope: scope)
            .injectedModifiers(viewStore.modifiers, scope: scope)
    }
}
