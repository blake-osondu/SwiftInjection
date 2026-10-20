//
//  ColorInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ColorInsertable: View {
    let viewStore: ColorViewStore

    var body: some View {
        ScopeReader { scope in
            Color(uiColor: UIColor.hex(scope.string(viewStore.color, default: "#00000000")))
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
