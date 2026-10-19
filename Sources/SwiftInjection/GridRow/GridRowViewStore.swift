//
//  GridRowViewStore.swift
//  SwiftInjection
//

import Foundation

public struct GridRowViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// Vertical alignment.
    public var alignment: InjectedExpression?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], alignment: InjectedExpression? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.alignment = alignment
        self.children = children
    }
}
