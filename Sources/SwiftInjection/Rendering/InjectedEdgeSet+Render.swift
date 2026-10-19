//
//  InjectedEdgeSet+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedEdgeSet {
    var render: Edge.Set {
        switch self {
        case .all: return Edge.Set.all
        case .bottom: return Edge.Set.bottom
        case .horizontal: return Edge.Set.horizontal
        case .leading: return Edge.Set.leading
        case .top: return Edge.Set.top
        case .trailing: return Edge.Set.trailing
        case .vertical: return Edge.Set.vertical
        }
    }
}
