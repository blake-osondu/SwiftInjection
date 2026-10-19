//
//  InjectedAlert.swift
//  SwiftInjectionCore
//

import Foundation

/// Used by the `alert` modifier:
/// `{"alert": {"isPresented": "showDelete", "alert": {"title": "Delete?", "message": "This can't be undone.",
///   "buttons": [{"label": "Delete", "role": "destructive", "action": [{"call": "deleteItem"}]},
///               {"label": "Cancel", "role": "cancel"}]}}}`
public struct InjectedAlert: Codable {
    public var title: InjectedExpression
    public var message: InjectedExpression?
    /// No buttons shows SwiftUI's default OK button.
    @OrEmpty public var buttons: [InjectedAlertButton]

    public init(title: InjectedExpression, message: InjectedExpression? = nil, buttons: [InjectedAlertButton] = []) {
        self.title = title
        self.message = message
        self.buttons = buttons
    }
}

public struct InjectedAlertButton: Codable {
    public var label: InjectedExpression
    public var role: InjectedButtonRole?
    @OrEmpty public var action: [InjectedAction]

    public init(label: InjectedExpression, role: InjectedButtonRole? = nil, action: [InjectedAction] = []) {
        self.label = label
        self.role = role
        self.action = action
    }
}

public enum InjectedButtonRole: String, Codable {
    case cancel, destructive
}
