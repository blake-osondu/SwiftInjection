//
//  Image_Ext.swift
//  
//
//  Created by Blake Osonduagwueki on 9/30/23.
//

import Foundation
import SwiftUI

extension Image {
    /// Applies the Image-only modifiers (`resizable`, `renderingMode`, `antialiased`), which must run
    /// before the image is erased to a View. Other modifiers are ignored here.
    func applyImageModifiers(_ modifiers: [InjectedModifier], scope: StateScope) -> Image {
        modifiers.reduce(self) { image, modifier in
            switch modifier {
            case let .antialiased(isActive):
                return scope.resolve(isActive, as: Bool.self).map { image.antialiased($0) } ?? image
            case let .resizable(capInsets, resizingMode):
                return image.resizable(capInsets: capInsets?.render ?? EdgeInsets(),
                                       resizingMode: scope.resolve(resizingMode, as: InjectedResizingMode.self)?.render ?? .stretch)
            case let .renderingMode(mode):
                return image.renderingMode(scope.resolve(mode, as: InjectedImageRenderingMode.self)?.render)
            default:
                return image
            }
        }
    }
}
