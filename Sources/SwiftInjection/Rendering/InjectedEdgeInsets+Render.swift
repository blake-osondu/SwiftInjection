//
//  InjectedEdgeInsets+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedEdgeInSets {
    var render: EdgeInsets {
        .init(top: CGFloat(top), leading: CGFloat(leading), bottom: CGFloat(bottom), trailing: CGFloat(trailing))
    }
}
