//
//  GroupViewStore.swift
//  SwiftInjection
//

import Foundation
/// Applies modifiers to several children without adding layout.
public struct GroupViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.children = children
    }
}
