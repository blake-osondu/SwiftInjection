//
//  InjectedAlert+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedButtonRole {
    var render: ButtonRole {
        switch self {
        case .cancel: return .cancel
        case .destructive: return .destructive
        }
    }
}
