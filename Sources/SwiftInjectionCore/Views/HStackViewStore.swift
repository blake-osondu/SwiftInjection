//
//  HStackViewStore.swift
//  SwiftInjection
//

import Foundation
/// Used by `hStack` and `lazyHStack`.
public struct HStackViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// "top", "center", "bottom", "firstTextBaseline" or "lastTextBaseline"
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
