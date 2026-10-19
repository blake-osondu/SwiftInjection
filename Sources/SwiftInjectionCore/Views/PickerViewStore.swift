//
//  PickerViewStore.swift
//  SwiftInjection
//

import Foundation

/// Options come from the array at `items`. Each option is rendered by `content` (default: the item as text)
/// with the item available as `item` (or the name in `itemName`) and its position as `index`.
/// The value written to `selection` is `value` evaluated for the option (default: the item itself).
///
/// `{"picker": {"title": "Size", "selection": "order.size", "items": "sizes",
///              "content": {"text": {"value": {"var": "item.label"}}}, "value": {"var": "item.id"}}}`
public struct PickerViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var selection: String
    public var items: String
    public var itemName: String?
    public var title: InjectedExpression?
    public var label: InjectedView?
    public var content: InjectedView?
    public var value: InjectedExpression?

    public init(id: String = "", modifiers: [InjectedModifier] = [], selection: String, items: String,
                itemName: String? = nil, title: InjectedExpression? = nil, label: InjectedView? = nil,
                content: InjectedView? = nil, value: InjectedExpression? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.selection = selection
        self.items = items
        self.itemName = itemName
        self.title = title
        self.label = label
        self.content = content
        self.value = value
    }
}
