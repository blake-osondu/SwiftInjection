//
//  ButtonViewStore.swift
//  SwiftInjection
//

import Foundation

/// `{"button": {"title": "Save", "action": [{"set": "saved", "to": true}]}}` or a custom `label` view.
public struct ButtonViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var title: InjectedExpression?
    public var label: InjectedView?
    public var role: InjectedButtonRole?
    @OrEmpty public var action: [InjectedAction]

    public init(id: String = "", modifiers: [InjectedModifier] = [], title: InjectedExpression? = nil,
                label: InjectedView? = nil, role: InjectedButtonRole? = nil, action: [InjectedAction] = []) {
        self.id = id
        self.modifiers = modifiers
        self.title = title
        self.label = label
        self.role = role
        self.action = action
    }
}
