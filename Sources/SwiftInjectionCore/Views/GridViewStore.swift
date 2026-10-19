//
//  GridViewStore.swift
//  SwiftInjection
//

import Foundation
/// Children are usually `gridRow`s.
public struct GridViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var alignment: InjectedExpression?
    public var horizontalSpacing: InjectedExpression?
    public var verticalSpacing: InjectedExpression?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], alignment: InjectedExpression? = nil, horizontalSpacing: InjectedExpression? = nil, verticalSpacing: InjectedExpression? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.children = children
    }
}
