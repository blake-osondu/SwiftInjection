//
//  InjectedDatePickerComponents.swift
//  SwiftInjection
//

import SwiftUI

public enum InjectedDatePickerComponents: String, Codable {
    case date, hourAndMinute
}

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
