//
//  InjectedDatePickerComponents+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension Array where Element == InjectedDatePickerComponents {
    var render: DatePickerComponents {
        reduce(into: []) { components, component in
            switch component {
            case .date: components.insert(.date)
            case .hourAndMinute: components.insert(.hourAndMinute)
            }
        }
    }
}
