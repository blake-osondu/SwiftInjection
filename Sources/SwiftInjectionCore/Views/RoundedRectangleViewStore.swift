//
//  RoundedRectangleViewStore.swift
//  SwiftInjection
//

import Foundation

public struct RoundedRectangleViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// Uniform radius; or give `cornerWidth`/`cornerHeight` for elliptical corners.
    public var cornerRadius: InjectedExpression?
    public var cornerWidth: InjectedExpression?
    public var cornerHeight: InjectedExpression?
    /// "circular" or "continuous"
    public var style: InjectedExpression?

    public init(id: String = "", modifiers: [InjectedModifier] = [], cornerRadius: InjectedExpression? = nil, cornerWidth: InjectedExpression? = nil, cornerHeight: InjectedExpression? = nil, style: InjectedExpression? = nil) {
        self.id = id
        self.modifiers = modifiers
        self.cornerRadius = cornerRadius
        self.cornerWidth = cornerWidth
        self.cornerHeight = cornerHeight
        self.style = style
    }
}
