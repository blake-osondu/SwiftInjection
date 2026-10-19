//
//  ScrollViewStore.swift
//  SwiftInjection
//

import Foundation
/// Children are stacked along the scroll axis.
public struct ScrollViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// "vertical" (default), "horizontal" or "both"
    public var axes: InjectedAxes?
    public var showsIndicators: InjectedExpression?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], axes: InjectedAxes? = nil, showsIndicators: InjectedExpression? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.children = children
    }
}
