//
//  UIColor_Ext.swift
//  Insertable
//
//  Created by Blake Osonduagwueki on 8/21/23.
//

import Foundation
import SwiftUI
import UIKit
import SwiftInjectionCore

public extension Color {
    static var random: Color {
        Color(UIColor.random)
    }
}

public extension UIColor {
    static var random: UIColor {
        [UIColor.red, UIColor.blue, UIColor.gray, UIColor.green].randomElement()!
    }
    static let hex: (String) -> UIColor = { hex in
        var sanitizedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitizedHex = sanitizedHex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var alpha: CGFloat = 1.0

        if sanitizedHex.count == 8 {
            // Extract alpha value from the hex string (if present)
            let alphaHex = sanitizedHex.prefix(2)
            sanitizedHex = String(sanitizedHex.dropFirst(2))
            
            Scanner(string: String(alphaHex)).scanHexInt64(&rgb)
            alpha = CGFloat(rgb) / 255.0
        }

        Scanner(string: sanitizedHex).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
