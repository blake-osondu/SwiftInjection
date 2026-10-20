//
//  InjectedAxes+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedAxes {
    var render: Axis.Set {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        case .both: return [.horizontal, .vertical]
        }
    }
}
