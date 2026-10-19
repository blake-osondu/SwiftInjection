//
//  Shape_Ext.swift
//
//
//  Created by Blake Osonduagwueki on 10/2/23.
//

import Foundation
import SwiftUI
import SwiftInjectionCore

extension Shape {
    /// Applies the shape-only `path` modifier, then the general modifiers.
    func applyShapeModifiers(_ modifiers: [InjectedModifier], scope: StateScope) -> some View {
        let shape = modifiers.reduce(AnyShape(self)) { shape, modifier in
            guard case let .path(x, y, width, height) = modifier else { return shape }
            let rect = CGRect(x: scope.resolve(x, as: CGFloat.self) ?? 0,
                              y: scope.resolve(y, as: CGFloat.self) ?? 0,
                              width: scope.resolve(width, as: CGFloat.self) ?? 0,
                              height: scope.resolve(height, as: CGFloat.self) ?? 0)
            return AnyShape(shape.path(in: rect))
        }
        return shape.injectedModifiers(modifiers, scope: scope)
    }
}
