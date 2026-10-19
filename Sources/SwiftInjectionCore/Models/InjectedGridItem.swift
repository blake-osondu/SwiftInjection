//
//  InjectedGridItem.swift
//  SwiftInjectionCore
//

import Foundation

/// A lazy-grid column or row: `{"size": "fixed", "value": 100}`, `{"size": "flexible", "minimum": 50}`,
/// `{"size": "adaptive", "minimum": 80, "maximum": 120}`.
public struct InjectedGridItem: Codable {
    public enum Size: String, Codable {
        case fixed, flexible, adaptive
    }

    public var size: Size?
    /// The width (or height) for `fixed` items.
    public var value: Double?
    public var minimum: Double?
    public var maximum: Double?
    public var spacing: Double?
    public var alignment: InjectedAlignment?

    public init(size: Size? = nil, value: Double? = nil, minimum: Double? = nil, maximum: Double? = nil,
                spacing: Double? = nil, alignment: InjectedAlignment? = nil) {
        self.size = size
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.spacing = spacing
        self.alignment = alignment
    }
}
