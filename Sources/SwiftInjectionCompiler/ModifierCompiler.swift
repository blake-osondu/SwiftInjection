//
//  ModifierCompiler.swift
//  SwiftInjectionCompiler
//

import Foundation
import SwiftSyntax
import SwiftInjectionCore

extension CompilerContext {

    func modifier(_ name: String, _ args: Arguments, at call: FunctionCallExprSyntax) -> InjectedModifier? {
        let first = args.unlabeled.first
        // Point at `.name(…)` rather than the start of the whole chain.
        let location = Syntax(call.calledExpression.as(MemberAccessExprSyntax.self)?.declName) ?? Syntax(call)
        switch name {
        // MARK: Text
        case "font":
            guard let first else { break }
            if let member = first.as(MemberAccessExprSyntax.self), member.base == nil || member.base?.trimmedDescription == "Font" {
                return option(first, InjectedSystemFont.self, "font").map { .systemFont(font: $0) }
            }
            if let custom = first.as(FunctionCallExprSyntax.self),
               custom.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "custom" {
                let customArgs = Arguments(custom)
                guard let fontName = customArgs.unlabeled.first.flatMap(expression), let size = customArgs.labeled["size"].flatMap(number) else {
                    return nil
                }
                return .font(name: fontName.expression, size: size)
            }
            error("Supported fonts: text styles like .title, and .custom(\"Name\", size:)", at: first)
            return nil
        case "fontWeight":
            return first.flatMap { option($0, InjectedFontWeight.self, "font weight") }.map { .fontWeight(weight: $0) }
        case "bold", "italic", "monospaced":
            var isActive: InjectedExpression?
            if let first {
                guard let value = boolean(first, name) else { return nil }
                isActive = value
            }
            return name == "bold" ? .bold(isActive: isActive) : name == "italic" ? .italic(isActive: isActive) : .monospaced(isActive: isActive)
        case "monospacedDigit":
            return .monospacedDigit
        case "underline", "strikethrough":
            var isActive: InjectedExpression?
            if let first {
                guard let value = boolean(first, name) else { return nil }
                isActive = value
            }
            let color = args.labeled["color"].flatMap { self.color($0) }
            return name == "underline" ? .underline(isActive: isActive, color: color) : .strikethrough(isActive: isActive, color: color)
        case "lineLimit":
            guard let first else { break }
            if first.is(NilLiteralExprSyntax.self) { return .lineLimit(limit: nil) }
            return number(first).map { .lineLimit(limit: $0) }
        case "multilineTextAlignment":
            return first.flatMap { option($0, InjectedTextAlignment.self, "text alignment") }.map { .multilineTextAlignment(alignment: $0) }
        case "kerning", "tracking":
            return first.flatMap(number).map { name == "kerning" ? .kerning(value: $0) : .tracking(value: $0) }
        case "minimumScaleFactor":
            return first.flatMap(number).map { .minimumScaleFactor(factor: $0) }

        // MARK: Layout
        case "padding":
            var edges: InjectedExpression?
            var length: InjectedExpression?
            for argument in args.unlabeled {
                if argument.is(MemberAccessExprSyntax.self) {
                    guard let value = option(argument, InjectedEdgeSet.self, "edge set") else { return nil }
                    edges = value
                } else {
                    guard let value = number(argument) else { return nil }
                    length = value
                }
            }
            return .padding(edges: edges, length: length)
        case "frame":
            var values: [String: InjectedExpression] = [:]
            for (label, argument) in args.labeled where label != "alignment" {
                guard ["width", "height", "minWidth", "idealWidth", "maxWidth", "minHeight", "idealHeight", "maxHeight"].contains(label) else {
                    error("Unsupported frame argument '\(label)'", at: argument)
                    return nil
                }
                guard let value = dimension(argument) else { return nil }
                values[label] = value
            }
            var alignment: InjectedExpression?
            if let argument = args.labeled["alignment"] {
                guard let value = option(argument, InjectedAlignment.self, "alignment") else { return nil }
                alignment = value
            }
            return .frame(width: values["width"], height: values["height"], minWidth: values["minWidth"],
                          idealWidth: values["idealWidth"], maxWidth: values["maxWidth"], minHeight: values["minHeight"],
                          idealHeight: values["idealHeight"], maxHeight: values["maxHeight"], alignment: alignment)
        case "position":
            return .position(x: args.labeled["x"].flatMap(number), y: args.labeled["y"].flatMap(number))
        case "layoutPriority":
            return first.flatMap(number).map { .layoutPriority(priority: $0) }
        case "fixedSize":
            return .fixedSize(horizontal: args.labeled["horizontal"].flatMap { boolean($0, "horizontal") },
                              vertical: args.labeled["vertical"].flatMap { boolean($0, "vertical") })
        case "ignoresSafeArea":
            let edges = args.labeled["edges"] ?? args.unlabeled.dropFirst().first
            return .ignoresSafeArea(edges: edges.flatMap { option($0, InjectedEdgeSet.self, "edge set") })

        // MARK: Appearance
        case "foregroundColor", "foregroundStyle", "tint":
            return first.flatMap { color($0) }.map { .foregroundColor(color: $0) }
        case "background":
            if let closure = args.trailing ?? args.closure("content") {
                guard let views = viewList(closure.statements) else { return nil }
                return .background(content: single(views))
            }
            guard let first else { break }
            if let hex = color(first, reportErrors: false) {
                return .background(content: .color(viewStore: ColorViewStore(color: hex)))
            }
            return view(first).map { .background(content: $0) }
        case "cornerRadius":
            return first.flatMap(number).map { .cornerRadius(radius: $0) }
        case "opacity":
            return first.flatMap(number).map { .opacity(value: $0) }
        case "blur":
            return args.labeled["radius"].flatMap(number).map { .blur(radius: $0) }
        case "brightness":
            return first.flatMap(number).map { .brightness(amount: $0) }
        case "shadow":
            return .shadow(color: args.labeled["color"].flatMap { color($0) }, radius: args.labeled["radius"].flatMap(number),
                           x: args.labeled["x"].flatMap(number), y: args.labeled["y"].flatMap(number))
        case "border":
            guard let first, let hex = color(first) else { return nil }
            return .border(color: hex, width: args.labeled["width"].flatMap(number))
        case "imageScale":
            return first.flatMap { option($0, InjectedImageScale.self, "image scale") }.map { .imageScale(scale: $0) }
        case "resizable":
            return .resizable()
        case "renderingMode":
            return first.flatMap { option($0, InjectedImageRenderingMode.self, "rendering mode") }.map { .renderingMode(mode: $0) }

        // MARK: Controls & events
        case "disabled":
            return first.flatMap { boolean($0, "disabled") }.map { .disabled(isDisabled: $0) }
        case "buttonStyle":
            return first.flatMap { option($0, InjectedButtonStyle.self, "button style") }.map { .buttonStyle(style: $0) }
        case "onAppear", "onDisappear":
            guard let closure = args.trailing ?? args.closure("perform"), let actions = actions(closure) else { return nil }
            return name == "onAppear" ? .onAppear(do: actions) : .onDisappear(do: actions)
        case "onTapGesture":
            guard let closure = args.trailing ?? args.closure("perform"), let actions = actions(closure) else { return nil }
            return .onTapGesture(count: args.labeled["count"].flatMap(number), do: actions)
        default:
            error("Modifier '.\(name)' isn't supported in v1", at: location)
            return nil
        }
        error("Unsupported use of '.\(name)': check its arguments", at: location)
        return nil
    }

    // MARK: - Colors

    /// A color as the runtime's `#AARRGGBB` hex: `.red`, `Color.blue`, `.red.opacity(0.5)`,
    /// `Color(red:green:blue:opacity:)` with literal components.
    func color(_ syntax: ExprSyntax, reportErrors: Bool = true) -> InjectedExpression? {
        guard let argb = colorValue(syntax) else {
            if reportErrors {
                error("Unsupported color '\(syntax.trimmedDescription)': use a named color like .blue or Color(red:green:blue:)", at: syntax)
            }
            return nil
        }
        return .literal(.string(String(format: "#%02X%02X%02X%02X", argb.a, argb.r, argb.g, argb.b)))
    }

    private func colorValue(_ syntax: ExprSyntax) -> (a: Int, r: Int, g: Int, b: Int)? {
        if let member = syntax.as(MemberAccessExprSyntax.self) {
            guard member.base == nil || member.base?.trimmedDescription == "Color",
                  let rgb = Self.namedColors[member.declName.baseName.text] else { return nil }
            return rgb
        }
        guard let call = syntax.as(FunctionCallExprSyntax.self) else { return nil }
        let args = Arguments(call)
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "opacity",
           let base = member.base, var rgb = colorValue(base), let opacity = args.unlabeled.first.flatMap(literalNumber) {
            rgb.a = Int((Double(rgb.a) * opacity).rounded())
            return rgb
        }
        if call.calledExpression.trimmedDescription == "Color",
           let red = args.labeled["red"].flatMap(literalNumber), let green = args.labeled["green"].flatMap(literalNumber),
           let blue = args.labeled["blue"].flatMap(literalNumber) {
            let opacity = args.labeled["opacity"].flatMap(literalNumber) ?? 1
            let channel = { (value: Double) in Int((min(max(value, 0), 1) * 255).rounded()) }
            return (channel(opacity), channel(red), channel(green), channel(blue))
        }
        return nil
    }

    private func literalNumber(_ syntax: ExprSyntax) -> Double? {
        if let integer = syntax.as(IntegerLiteralExprSyntax.self) { return Double(integer.literal.text) }
        if let float = syntax.as(FloatLiteralExprSyntax.self) { return Double(float.literal.text) }
        return nil
    }

    /// iOS system colors (light appearance). Hex colors don't adapt to dark mode.
    static let namedColors: [String: (a: Int, r: Int, g: Int, b: Int)] = [
        "red": (255, 0xFF, 0x3B, 0x30), "orange": (255, 0xFF, 0x95, 0x00), "yellow": (255, 0xFF, 0xCC, 0x00),
        "green": (255, 0x34, 0xC7, 0x59), "mint": (255, 0x00, 0xC7, 0xBE), "teal": (255, 0x30, 0xB0, 0xC7),
        "cyan": (255, 0x32, 0xAD, 0xE6), "blue": (255, 0x00, 0x7A, 0xFF), "indigo": (255, 0x58, 0x56, 0xD6),
        "purple": (255, 0xAF, 0x52, 0xDE), "pink": (255, 0xFF, 0x2D, 0x55), "brown": (255, 0xA2, 0x84, 0x5E),
        "gray": (255, 0x8E, 0x8E, 0x93), "black": (255, 0x00, 0x00, 0x00), "white": (255, 0xFF, 0xFF, 0xFF),
        "clear": (0, 0x00, 0x00, 0x00),
    ]
}
