//
//  ColorViewStore.swift
//  SwiftInjection
//

import Foundation

/// `{"color": {"color": "#FF8800"}}`
public struct ColorViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// Hex string.
    public var color: InjectedExpression

    public init(id: String = "", modifiers: [InjectedModifier] = [], color: InjectedExpression) {
        self.id = id
        self.modifiers = modifiers
        self.color = color
    }
}
