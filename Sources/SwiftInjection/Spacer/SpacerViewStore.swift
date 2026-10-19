//
//  SpacerViewStore.swift
//  SwiftInjection
//

import Foundation

public struct SpacerViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var minLength: InjectedExpression?

    public init(id: String = "", modifiers: [InjectedModifier] = [], minLength: InjectedExpression? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.minLength = minLength
    }
}
