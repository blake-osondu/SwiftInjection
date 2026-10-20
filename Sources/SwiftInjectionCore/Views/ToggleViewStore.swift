//
//  ToggleViewStore.swift
//  SwiftInjectionCore
//

import Foundation

/// `{"toggle": {"isOn": "settings.notifications", "title": "Notifications"}}` or a custom `label` view.
public struct ToggleViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// The state path holding the Bool.
    public var isOn: String
    public var title: InjectedExpression?
    public var label: InjectedView?

    public init(id: String = "", modifiers: [InjectedModifier] = [], isOn: String,
                title: InjectedExpression? = nil, label: InjectedView? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.isOn = isOn
        self.title = title
        self.label = label
    }
}
