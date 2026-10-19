//
//  ControlGroupInsertable.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

struct ControlGroupInsertable: View {
    let viewStore: ControlGroupViewStore

    var body: some View {
        ScopeReader { scope in
            Group {
                if let label = viewStore.label {
                    ControlGroup {
                        InjectedChildren(viewStore.children)
                    } label: {
                        InjectedContent(label)
                    }
                } else {
                    ControlGroup {
                        InjectedChildren(viewStore.children)
                    }
                }
            }
                .injectedModifiers(viewStore.modifiers, scope: scope)
        }
    }
}
