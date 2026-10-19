//
//  NavigationStackViewStore.swift
//  SwiftInjection
//

import Foundation

public struct NavigationStackViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var root: InjectedView

    public init(id: String = "", modifiers: [InjectedModifier] = [], root: InjectedView) {
        self.id = id
        self.modifiers = modifiers
        self.root = root
    }
}
