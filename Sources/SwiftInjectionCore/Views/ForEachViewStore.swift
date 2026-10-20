//
//  ForEachViewStore.swift
//  SwiftInjection
//

import Foundation

/// Renders `content` once per element of the array at `items`. Inside, `item` (or `itemName`) aliases the
/// element, so reads and writes like `{"set": "item.done", ...}` reach the real state, and `index` is its position.
/// `identity` (evaluated per item, e.g. `{"var": "item.id"}`) keeps rows stable when the array changes;
/// without it rows are identified by position.
///
/// `{"forEach": {"items": "todos", "identity": {"var": "item.id"}, "content": {"text": {"value": {"var": "item.title"}}}}}`
public struct ForEachViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var items: String
    public var itemName: String?
    public var identity: InjectedExpression?
    public var content: InjectedView

    public init(id: String = "", modifiers: [InjectedModifier] = [], items: String, itemName: String? = nil,
                identity: InjectedExpression? = nil, content: InjectedView) {
        self.id = id
        self.modifiers = modifiers
        self.items = items
        self.itemName = itemName
        self.identity = identity
        self.content = content
    }
}
