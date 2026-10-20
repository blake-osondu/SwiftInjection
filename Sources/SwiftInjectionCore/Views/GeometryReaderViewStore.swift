//
//  GeometryReaderViewStore.swift
//  SwiftInjection
//

import Foundation

/// Renders `content` with a read-only `geometry` local (or `name`):
/// `{"width", "height", "safeArea": {"top", "leading", "bottom", "trailing"}}`.
public struct GeometryReaderViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    public var name: String?
    public var content: InjectedView

    public init(id: String = "", modifiers: [InjectedModifier] = [], name: String? = nil, content: InjectedView) {
        self.id = id
        self.modifiers = modifiers
        self.name = name
        self.content = content
    }
}
