//
//  InjectedModifier_Ext.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 9/5/23.
//

import Foundation
import SwiftUI

extension StateSignal {
    /// A read-only StateScope over the current parameter-slot state, so modifiers can evaluate
    /// expressions while components still pass StateSignal around. Writes (e.g. dismissing a sheet)
    /// don't reach the signal; that's resolved once components move to StateScope.
    var snapshotScope: StateScope {
        let store = StateStore(value.runtimeValue)
        return StateScope(store: store)
    }
}

public extension View {

    func addModifier(injectedModifier: InjectedModifier, stateSignal: StateSignal, container: ViewStoresContainer) -> some View {
        modifier(ModifierStore(modifier: injectedModifier, scope: stateSignal.snapshotScope, state: stateSignal, container: container))
    }

    func addModifiers(mods: [InjectedModifier], stateSignal: StateSignal, container: ViewStoresContainer) -> some View {
        let scope = stateSignal.snapshotScope
        return mods.reduce(AnyView(self)) { view, modifier in
            AnyView(view.modifier(ModifierStore(modifier: modifier, scope: scope, state: stateSignal, container: container)))
        }
    }
}
