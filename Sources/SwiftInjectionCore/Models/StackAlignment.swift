//
//  StackAlignment.swift
//  SwiftInjectionCore
//

import Foundation

public enum InjectedHorizontalAlignment: String, Codable {
    case center, leading, trailing, listRowSeparatorLeading, listRowSeparatorTrailing
}

public enum InjectedVerticalAlignment: String, Codable {
    case bottom, center, top, firstTextBaseline, lastTextBaseline
}

public enum InjectedAlignment: String, Codable {
    case trailing, leading, center, top, bottom, bottomLeading, bottomTrailing, topLeading, topTrailing, centerFirstTextBaseline, centerLastTextBaseline, leadingFirstTextBaseline, leadingLastTextBaseline, trailingFirstTextBaseline, trailingLastTextBaseline
}
