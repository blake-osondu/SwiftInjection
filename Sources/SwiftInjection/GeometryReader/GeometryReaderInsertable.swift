//
//  GeometryReaderInsertable.swift
//  SwiftInjection
//

import SwiftUI

struct GeometryReaderInsertable: View {
    let viewStore: GeometryReaderViewStore

    var body: some View {
        ScopeReader { scope in
            GeometryReader { proxy in
                InjectedContent(viewStore.content)
                    .scopeLocals(scope.child(viewStore.name ?? "geometry", value: Self.geometry(proxy.size, proxy.safeAreaInsets)).locals)
            }
            .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }

    static func geometry(_ size: CGSize, _ insets: EdgeInsets) -> RuntimeValue {
        [
            "width": .number(Double(size.width)),
            "height": .number(Double(size.height)),
            "safeArea": [
                "top": .number(Double(insets.top)),
                "leading": .number(Double(insets.leading)),
                "bottom": .number(Double(insets.bottom)),
                "trailing": .number(Double(insets.trailing)),
            ],
        ]
    }
}
