//
//  InjectedViewStoreAddModifier.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 9/13/23.
//

import Foundation

public extension InjectedView {

    func addModifier(modifier: InjectedModifier) -> InjectedView {
        self |> prop(\.modifiers)({ $0.appending(modifier)})
    }

    /// `view.modifiers(.padding(length: 8), .foregroundColor(color: .var("tint")))`
    func modifiers(_ modifiers: InjectedModifier...) -> InjectedView {
        modifiers.reduce(self) { $0.addModifier(modifier: $1) }
    }
}


