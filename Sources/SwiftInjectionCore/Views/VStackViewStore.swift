//
//  VStackViewStore.swift
//  SwiftInjection
//

import Foundation
/// Used by `vStack` and `lazyVStack`. `{"vStack": {"alignment": "leading", "spacing": 8, "children": [...]}}`
public struct VStackViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// "leading", "center" or "trailing"
    public var alignment: InjectedExpression?
    public var spacing: InjectedExpression?
    /// Lazy stacks and grids only: "sectionHeaders", "sectionFooters".
    @OrEmpty public var pinnedViews: [InjectedPinnedScrollableViews]
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], alignment: InjectedExpression? = nil, spacing: InjectedExpression? = nil, pinnedViews: [InjectedPinnedScrollableViews] = [], children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.children = children
    }
}
