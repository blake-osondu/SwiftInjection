//
//  EmptyViewStore.swift
//  
//
//  Created by Blake Osonduagwueki on 9/29/23.
//

import Foundation

public struct EmptyViewStore: Codable {
    public var id: String = ""
    public var modifiers: [InjectedModifier] = []
}
