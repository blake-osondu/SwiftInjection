//
//  InjectedEdgeSet.swift
//  SwiftInjectionCore
//

import Foundation

public enum InjectedEdgeSet: String, Codable, CaseIterable {
    case all
    case bottom
    case horizontal
    case leading
    case top
    case trailing
    case vertical
}
