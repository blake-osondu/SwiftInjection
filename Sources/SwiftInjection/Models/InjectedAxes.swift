//
//  InjectedAxes.swift
//  SwiftInjection
//

import SwiftUI

public enum InjectedAxes: String, Codable {
    case horizontal, vertical, both

    var render: Axis.Set {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        case .both: return [.horizontal, .vertical]
        }
    }
}
