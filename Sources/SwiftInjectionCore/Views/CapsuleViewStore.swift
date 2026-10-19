//
//  CapsuleViewStore.swift
//  SwiftInjection
//

import Foundation

public struct CapsuleViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// "circular" or "continuous"
    public var style: InjectedExpression?

    public init(id: String = "", modifiers: [InjectedModifier] = [], style: InjectedExpression? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.style = style
    }
}
