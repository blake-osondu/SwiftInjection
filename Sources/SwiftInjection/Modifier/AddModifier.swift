//
//  AddModifier.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 9/5/23.
//

import SwiftUI
import SwiftInjectionCore

extension View {
    /// Applies payload modifiers in order, evaluating their arguments in `scope`.
    func addModifiers(mods: [InjectedModifier], scope: StateScope) -> AnyView {
        mods.reduce(AnyView(self)) { view, modifier in
            AnyView(view.modifier(ModifierStore(modifier: modifier, scope: scope)))
        }
    }
}
