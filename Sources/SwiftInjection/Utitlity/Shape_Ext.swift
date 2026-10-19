//
//  Shape_Ext.swift
//  
//
//  Created by Blake Osonduagwueki on 10/4/23.
//

import Foundation
import SwiftUI

extension Shape {
    
    func addShapeModifiers(modifiers: [InjectedModifier], state: StateSignal, container: ViewStoresContainer) -> any View {
        let scope = state.snapshotScope
        let shape = modifiers.reduce(self as any Shape) { shape, modifier -> any Shape in
            guard case let .path(x, y, width, height) = modifier else { return shape }
            let rect = CGRect(x: scope.resolve(x, as: CGFloat.self) ?? 0,
                              y: scope.resolve(y, as: CGFloat.self) ?? 0,
                              width: scope.resolve(width, as: CGFloat.self) ?? 0,
                              height: scope.resolve(height, as: CGFloat.self) ?? 0)
            return shape.path(in: rect)
        }
        return shape.addModifiers(mods: modifiers, stateSignal: state, container: container)
    }
}
