//
//  TabViewStore.swift
//  SwiftInjection
//

import Foundation
/// Each child is a tab (give it a `tabItem` modifier). Tabs are tagged by index;
/// `selection` is the state path holding the selected index.
public struct TabViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var selection: String?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], selection: String? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.selection = selection
        self.children = children
    }
}
