//
//  NavigationLinkViewStore.swift
//  SwiftInjection
//

import Foundation

public struct NavigationLinkViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var destination: InjectedView
    public var label: InjectedView

    public init(id: String = "", modifiers: [InjectedModifier] = [], destination: InjectedView, label: InjectedView) {
        self.id = id
        self.modifiers = modifiers
        self.destination = destination
        self.label = label
    }
}
