//
//  TextViewStore.swift
//  SwiftInjection
//

import Foundation

/// `{"text": {"value": {"format": ["Hi {0}", {"var": "name"}]}}}`
public struct TextViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var value: InjectedExpression

    public init(id: String = "", modifiers: [InjectedModifier] = [], value: InjectedExpression) {
        self.id = id
        self.modifiers = modifiers
        self.value = value
    }
}
