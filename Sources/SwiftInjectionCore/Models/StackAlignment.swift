//
//  StackAlignment.swift
//  SwiftInjectionCore
//

import Foundation

public enum InjectedHorizontalAlignment: String, Codable, CaseIterable {
    case center, leading, trailing, listRowSeparatorLeading, listRowSeparatorTrailing
}

public enum InjectedVerticalAlignment: String, Codable, CaseIterable {
    case bottom, center, top, firstTextBaseline, lastTextBaseline
}

public enum InjectedAlignment: String, Codable, CaseIterable {
    case trailing, leading, center, top, bottom, bottomLeading, bottomTrailing, topLeading, topTrailing, centerFirstTextBaseline, centerLastTextBaseline, leadingFirstTextBaseline, leadingLastTextBaseline, trailingFirstTextBaseline, trailingLastTextBaseline
}
