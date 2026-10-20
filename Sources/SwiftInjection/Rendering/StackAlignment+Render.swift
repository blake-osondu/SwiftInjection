//
//  StackAlignment+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedHorizontalAlignment {
    var render: HorizontalAlignment {
        switch self {
        case .center:
            return HorizontalAlignment.center
        case .leading:
            return HorizontalAlignment.leading
        case .trailing:
            return HorizontalAlignment.trailing
        case .listRowSeparatorLeading:
            return HorizontalAlignment.listRowSeparatorLeading
        case .listRowSeparatorTrailing:
            return HorizontalAlignment.listRowSeparatorTrailing
        }
    }
}

extension InjectedVerticalAlignment {
    var render: VerticalAlignment {
        switch self {
        case .center:
            return VerticalAlignment.center
        case .top:
            return VerticalAlignment.top
        case .bottom:
            return VerticalAlignment.bottom
        case .firstTextBaseline:
            return VerticalAlignment.firstTextBaseline
        case .lastTextBaseline:
            return VerticalAlignment.lastTextBaseline
        }
    }
}

extension InjectedAlignment {
    var render: Alignment {
        switch self {
        case .trailing:
            return Alignment.trailing
        case .leading:
            return Alignment.leading
        case .center:
            return Alignment.center
        case .top:
            return Alignment.top
        case .bottom:
            return Alignment.bottom
        case .bottomLeading:
            return Alignment.bottomLeading
        case .bottomTrailing:
            return Alignment.bottomTrailing
        case .topLeading:
            return Alignment.topLeading
        case .topTrailing:
            return Alignment.topTrailing
        case .centerFirstTextBaseline:
            return Alignment.centerFirstTextBaseline
        case .centerLastTextBaseline:
            return Alignment.centerLastTextBaseline
        case .leadingFirstTextBaseline:
            return Alignment.leadingFirstTextBaseline
        case .leadingLastTextBaseline:
            return Alignment.leadingLastTextBaseline
        case .trailingFirstTextBaseline:
            return Alignment.trailingFirstTextBaseline
        case .trailingLastTextBaseline:
            return Alignment.trailingLastTextBaseline
        }
    }
}
