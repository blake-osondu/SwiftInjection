//
//  IfViewStore.swift
//  SwiftInjection
//

import Foundation

/// `{"if": {"condition": {"gt": [{"var": "count"}, 0]}, "then": {...}, "else": {...}}}`
public struct IfViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var condition: InjectedExpression
    public var then: InjectedView
    public var otherwise: InjectedView?

    enum CodingKeys: String, CodingKey {
        case id, modifiers, condition, then
        case otherwise = "else"
    }

    public init(id: String = "", modifiers: [InjectedModifier] = [], condition: InjectedExpression,
                then: InjectedView, otherwise: InjectedView? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.condition = condition
        self.then = then
        self.otherwise = otherwise
    }
}
