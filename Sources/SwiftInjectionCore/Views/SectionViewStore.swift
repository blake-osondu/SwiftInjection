//
//  SectionViewStore.swift
//  SwiftInjection
//

import Foundation
/// A `title`, or custom `header`/`footer` views.
public struct SectionViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var title: InjectedExpression?
    public var header: InjectedView?
    public var footer: InjectedView?
    @OrEmpty public var children: [InjectedView]

    public init(id: String = "", modifiers: [InjectedModifier] = [], title: InjectedExpression? = nil, header: InjectedView? = nil, footer: InjectedView? = nil, children: [InjectedView] = []) {
        self.id = id
        self.modifiers = modifiers
        self.title = title
        self.header = header
        self.footer = footer
        self.children = children
    }
}
