//
//  ZStackViewStore.swift
//  SwiftInjection
//

import Foundation
/// `{"zStack": {"alignment": "topLeading", "children": [...]}}`
public struct ZStackViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var alignment: InjectedExpression?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], alignment: InjectedExpression? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.alignment = alignment
        self.children = children
    }
}
