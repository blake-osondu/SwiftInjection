//
//  LazyVGridViewStore.swift
//  SwiftInjection
//

import Foundation
/// `{"lazyVGrid": {"columns": [{"size": "adaptive", "minimum": 80}], "children": [...]}}`
public struct LazyVGridViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var columns: [InjectedGridItem]
    /// Horizontal alignment.
    public var alignment: InjectedExpression?
    public var spacing: InjectedExpression?
    /// Lazy stacks and grids only: "sectionHeaders", "sectionFooters".
    @OrEmpty public var pinnedViews: [InjectedPinnedScrollableViews]
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], columns: [InjectedGridItem], alignment: InjectedExpression? = nil, spacing: InjectedExpression? = nil, pinnedViews: [InjectedPinnedScrollableViews] = [], children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.children = children
    }
}
