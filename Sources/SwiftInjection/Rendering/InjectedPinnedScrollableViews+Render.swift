//
//  InjectedPinnedScrollableViews+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension Array where Element == InjectedPinnedScrollableViews {
    var render: PinnedScrollableViews {
        reduce(into: []) { views, pinned in
            switch pinned {
            case .sectionHeaders: views.insert(.sectionHeaders)
            case .sectionFooters: views.insert(.sectionFooters)
            }
        }
    }
}
