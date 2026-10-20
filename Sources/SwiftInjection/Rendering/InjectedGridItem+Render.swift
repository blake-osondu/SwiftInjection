//
//  InjectedGridItem+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedGridItem {
    var render: GridItem {
        let gridSize: GridItem.Size
        switch size ?? .flexible {
        case .fixed:
            gridSize = .fixed(CGFloat(value ?? minimum ?? 0))
        case .flexible:
            gridSize = .flexible(minimum: CGFloat(minimum ?? 10), maximum: CGFloat(maximum ?? .infinity))
        case .adaptive:
            gridSize = .adaptive(minimum: CGFloat(minimum ?? 10), maximum: CGFloat(maximum ?? .infinity))
        }
        return GridItem(gridSize, spacing: spacing.map { CGFloat($0) }, alignment: alignment?.render)
    }
}
