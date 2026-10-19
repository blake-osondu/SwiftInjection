//
//  LazyHGridViewStore.swift
//  SwiftInjection
//

import Foundation

public struct LazyHGridViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var rows: [InjectedGridItem]
    /// Vertical alignment.
    public var alignment: InjectedExpression?
    public var spacing: InjectedExpression?
    /// Lazy stacks and grids only: "sectionHeaders", "sectionFooters".
    @OrEmpty public var pinnedViews: [InjectedPinnedScrollableViews]
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], rows: [InjectedGridItem], alignment: InjectedExpression? = nil, spacing: InjectedExpression? = nil, pinnedViews: [InjectedPinnedScrollableViews] = [], children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.children = children
    }
}
