//
//  Color+Hex.swift
//  SwiftInjectionAuthoring
//

import SwiftUI

extension Color {
    /// A color from a hex string (`#RRGGBB` or `#AARRGGBB`), so screens can use colors from data:
    /// `.foregroundColor(Color(hex: product.color))`. Renders in Previews; the compiler maps it to a
    /// state-driven color.
    public init(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: text).scanHexInt64(&value)
        let hasAlpha = text.count == 8
        let alpha = hasAlpha ? Double((value >> 24) & 0xFF) / 255 : 1
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: alpha)
    }
}
