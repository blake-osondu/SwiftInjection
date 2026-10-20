//
//  CustomViewStore.swift
//  SwiftInjectionCore
//

import Foundation

/// A view the host app registers by name (see `StateStore.components`). `props` are expressions evaluated in the
/// current scope; `on` maps event names the view can send to action lists.
///
/// `{"custom": {"name": "productCard", "props": {"id": {"var": "item.id"}}, "on": {"select": [{"set": "selected", "to": {"var": "item.id"}}]}}}`
public struct CustomViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var name: String
    @OrEmpty public var props: [String: InjectedExpression]
    @OrEmpty public var on: [String: [InjectedAction]]

    public init(id: String = "", modifiers: [InjectedModifier] = [], name: String,
                props: [String: InjectedExpression] = [:], on: [String: [InjectedAction]] = [:]) {
        self.id = id
        self.modifiers = modifiers
        self.name = name
        self.props = props
        self.on = on
    }
}
