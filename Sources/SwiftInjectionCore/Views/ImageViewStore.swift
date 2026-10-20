//
//  ImageViewStore.swift
//  SwiftInjection
//

import Foundation

/// Exactly one source is used, in order: `url` (AsyncImage), `systemName`, `name`.
/// `{"image": {"systemName": "star.fill"}}`, `{"image": {"url": {"var": "user.avatar"}, "placeholder": {...}}}`
public struct ImageViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var name: InjectedExpression?
    public var systemName: InjectedExpression?
    public var url: InjectedExpression?
    /// Scale for remote images (default 1).
    public var scale: InjectedExpression?
    public var placeholder: InjectedView?

    public init(id: String = "", modifiers: [InjectedModifier] = [], name: InjectedExpression? = nil,
                systemName: InjectedExpression? = nil, url: InjectedExpression? = nil,
                scale: InjectedExpression? = nil, placeholder: InjectedView? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.name = name
        self.systemName = systemName
        self.url = url
        self.scale = scale
        self.placeholder = placeholder
    }
}
