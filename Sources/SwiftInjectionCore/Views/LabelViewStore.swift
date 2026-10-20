//
//  LabelViewStore.swift
//  SwiftInjection
//

import Foundation

/// Either `title` with `systemImage`/`image`, or custom `titleView` and `iconView`.
public struct LabelViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var title: InjectedExpression?
    public var systemImage: InjectedExpression?
    public var image: InjectedExpression?
    public var titleView: InjectedView?
    public var iconView: InjectedView?

    public init(id: String = "", modifiers: [InjectedModifier] = [], title: InjectedExpression? = nil,
                systemImage: InjectedExpression? = nil, image: InjectedExpression? = nil,
                titleView: InjectedView? = nil, iconView: InjectedView? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.title = title
        self.systemImage = systemImage
        self.image = image
        self.titleView = titleView
        self.iconView = iconView
    }
}
