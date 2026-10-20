//
//  CircleViewStore.swift
//  SwiftInjection
//

import Foundation

public struct CircleViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]

    public init(id: String = "", modifiers: [InjectedModifier] = []) {
        self.id = id
        self.modifiers = modifiers
    }
}
