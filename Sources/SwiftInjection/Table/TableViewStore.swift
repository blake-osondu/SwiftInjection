//
//  TableViewStore.swift
//  SwiftInjection
//

import Foundation

/// One row per element of `items`; each column renders its `content` with `item`/`index` locals.
/// Before iOS 17.4 (and at compact widths) only the first column is shown.
///
/// `{"table": {"items": "people", "columns": [
///    {"title": "Name", "content": {"text": {"value": {"var": "item.name"}}}},
///    {"title": "Email", "content": {"text": {"value": {"var": "item.email"}}}}]}}`
public struct TableViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var items: String
    public var itemName: String?
    public var columns: [InjectedTableColumn]

    public init(id: String = "", modifiers: [InjectedModifier] = [], items: String, itemName: String? = nil,
                columns: [InjectedTableColumn]) {
        self.id = id
        self.modifiers = modifiers
        self.items = items
        self.itemName = itemName
        self.columns = columns
    }
}

public struct InjectedTableColumn: Codable {
    public var title: InjectedExpression
    public var content: InjectedView

    public init(title: InjectedExpression, content: InjectedView) {
        self.title = title
        self.content = content
    }
}
