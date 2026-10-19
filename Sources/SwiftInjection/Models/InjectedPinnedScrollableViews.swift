//
//  InjectedPinnedScrollableViews.swift
//  SwiftInjection
//

import SwiftUI

public enum InjectedPinnedScrollableViews: String, Codable {
    case sectionHeaders, sectionFooters
}

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
