//
//  ListViewStore.swift
//  SwiftInjection
//

import Foundation

/// Static `children` rows, followed by one row per element of `items` (see `forEach`).
public struct ListViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    @OrEmpty public var children: [InjectedView]
    public var items: String?
    public var itemName: String?
    public var identity: InjectedExpression?
    public var content: InjectedView?

    public init(id: String = "", modifiers: [InjectedModifier] = [], children: [InjectedView] = [],
                items: String? = nil, itemName: String? = nil, identity: InjectedExpression? = nil,
                content: InjectedView? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.children = children
        self.items = items
        self.itemName = itemName
        self.identity = identity
        self.content = content
    }
}
