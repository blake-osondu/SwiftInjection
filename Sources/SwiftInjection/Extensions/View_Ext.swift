//
//  View_Ext.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/17/23.
//

import Foundation
import SwiftUI
import Combine
import SwiftInjectionCore

public extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}


