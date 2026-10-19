//
//  InjectedFontWeight+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedFontWeight {
    var render: Font.Weight {
        switch self {
        case .black:
            return .black
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .light:
            return .light
        case .regular:
            return .thin
        case .thin:
            return .thin
        case .ultraLight:
            return .ultraLight
        }
    }
}
