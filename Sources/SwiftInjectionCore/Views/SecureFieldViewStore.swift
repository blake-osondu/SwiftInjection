//
//  SecureFieldViewStore.swift
//  SwiftInjection
//

import Foundation

/// Same shape as `field`.
public struct SecureFieldViewStore: Codable {
    @OrEmpty public var id: String
    @OrEmpty public var modifiers: [InjectedModifier]
    /// The state path the text is read from and written to.
    public var text: String
    /// Placeholder / accessibility title.
    public var title: InjectedExpression?
    public var prompt: InjectedExpression?
    @OrEmpty public var onSubmit: [InjectedAction]

    public init(id: String = "", modifiers: [InjectedModifier] = [], text: String, title: InjectedExpression? = nil,
                prompt: InjectedExpression? = nil, onSubmit: [InjectedAction] = []) {
        self.id = id
        self.modifiers = modifiers
        self.text = text
        self.title = title
        self.prompt = prompt
        self.onSubmit = onSubmit
    }
}
