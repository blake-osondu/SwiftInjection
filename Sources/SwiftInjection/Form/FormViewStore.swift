//
//  FormViewStore.swift
//  SwiftInjection
//

import Foundation

public struct FormViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.children = children
    }
}
