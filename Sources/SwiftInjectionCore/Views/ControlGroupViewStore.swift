//
//  ControlGroupViewStore.swift
//  SwiftInjection
//

import Foundation

public struct ControlGroupViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var label: InjectedView?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], label: InjectedView? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.label = label
        self.children = children
    }
}
