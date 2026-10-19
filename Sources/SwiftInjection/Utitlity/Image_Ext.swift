//
//  Image_Ext.swift
//  
//
//  Created by Blake Osonduagwueki on 9/30/23.
//

import Foundation
import SwiftUI

extension Image {
    func addModifiers(modifiers: [InjectedModifier], state: StateSignal, container: ViewStoresContainer) -> Image {
        modifiers.reduce(self) { partialResult, modifier in
            addModifier(modifier: modifier, state: state, container: container)
        }
    }
    
    func addModifier(modifier: InjectedModifier, state: StateSignal, container: ViewStoresContainer) -> Image {
        let scope = state.snapshotScope
        switch modifier {
        case let .antialiased(isActive):
            return scope.resolve(isActive, as: Bool.self).map { self.antialiased($0) } ?? self
        case let .resizable(capInsets, resizingMode):
            return self.resizable(capInsets: capInsets?.render ?? EdgeInsets(),
                                  resizingMode: scope.resolve(resizingMode, as: InjectedResizingMode.self)?.render ?? .stretch)
        case let .renderingMode(mode):
            return self.renderingMode(scope.resolve(mode, as: InjectedImageRenderingMode.self)?.render)
        default:
            return self
        }
    }
}
