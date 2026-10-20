//
//  InjectedEdgeInsets.swift
//  SwiftInjectionCore
//

import Foundation

public struct InjectedEdgeInSets: Codable {
    public var top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0

    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}
