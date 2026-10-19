//
//  IfViewStore.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 9/4/23.
//

import Foundation

public struct IfViewStore: Codable {
    public var id: String
    public var modifiers: [InjectedModifier]
    var conditionKey: String
    /// Takes precedence over `conditionKey` when present.
    var condition: InjectedExpression?
    var content: InjectedView
    init(id: String = "", modifiers: [InjectedModifier], conditionKey: String = "", condition: InjectedExpression? = nil, content: InjectedView) {
        self.id = id
        self.modifiers = modifiers
        self.conditionKey = conditionKey
        self.condition = condition
        self.content = content
    }
}
