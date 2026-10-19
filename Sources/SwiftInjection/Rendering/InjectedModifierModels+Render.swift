//
//  InjectedModifierModels+Render.swift
//  SwiftInjection
//

import SwiftUI
import SwiftInjectionCore

extension InjectedFontDesign {
    var render: Font.Design {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        }
    }
}

extension InjectedFontWidth {
    var render: Font.Width {
        switch self {
        case .compressed: return .compressed
        case .condensed: return .condensed
        case .standard: return .standard
        case .expanded: return .expanded
        }
    }
}

extension InjectedTextLineStylePattern {
    var render: Text.LineStyle.Pattern {
        switch self {
        case .solid: return .solid
        case .dot: return .dot
        case .dash: return .dash
        case .dashDot: return .dashDot
        case .dashDotDot: return .dashDotDot
        }
    }
}

extension InjectedTextTruncation {
    var render: Text.TruncationMode {
        switch self {
        case .head: return .head
        case .middle: return .middle
        case .tail: return .tail
        }
    }
}

extension InjectedBlendMode {
    var render: BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        case .sourceAtop: return .sourceAtop
        case .destinationOver: return .destinationOver
        case .destinationOut: return .destinationOut
        case .plusDarker: return .plusDarker
        case .plusLighter: return .plusLighter
        }
    }
}

extension InjectedTextAlignment {
    var render: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

extension InjectedImageScale {
    var render: Image.Scale {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }
}

extension InjectedAnimation {
    var render: Animation {
        switch self {
        case .default: return .default
        case .linear: return .linear
        case .easeIn: return .easeIn
        case .easeOut: return .easeOut
        case .easeInOut: return .easeInOut
        case .spring: return .spring()
        case .bouncy: return .interpolatingSpring(stiffness: 170, damping: 12)
        case .smooth: return .spring(response: 0.5, dampingFraction: 1)
        case .snappy: return .spring(response: 0.3, dampingFraction: 0.85)
        }
    }
}

extension InjectedSymbolRenderingMode {
    var render: SymbolRenderingMode {
        switch self {
        case .monochrome: return .monochrome
        case .hierarchical: return .hierarchical
        case .multicolor: return .multicolor
        case .palette: return .palette
        }
    }
}

extension InjectedResizingMode {
    var render: Image.ResizingMode {
        switch self {
        case .stretch: return .stretch
        case .tile: return .tile
        }
    }
}

extension InjectedImageRenderingMode {
    var render: Image.TemplateRenderingMode {
        switch self {
        case .original: return .original
        case .template: return .template
        }
    }
}

extension InjectedVisbility {
    var render: Visibility {
        switch self {
        case .automatic: return .automatic
        case .visible: return .visible
        case .hidden: return .hidden
        }
    }
}

extension InjectedPopoverAttachmentAnchor {
    var render: PopoverAttachmentAnchor {
        switch self {
        case .bounds: return .rect(.bounds)
        case .top: return .point(.top)
        case .bottom: return .point(.bottom)
        case .leading: return .point(.leading)
        case .trailing: return .point(.trailing)
        case .center: return .point(.center)
        }
    }
}

extension InjectedEdge {
    var render: Edge {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

extension InjectedKeyboardType {
    var render: UIKeyboardType {
        switch self {
        case .default: return .default
        case .asciiCapable: return .asciiCapable
        case .numbersAndPunctuation: return .numbersAndPunctuation
        case .URL: return .URL
        case .numberPad: return .numberPad
        case .phonePad: return .phonePad
        case .namePhonePad: return .namePhonePad
        case .emailAddress: return .emailAddress
        case .decimalPad: return .decimalPad
        case .twitter: return .twitter
        case .webSearch: return .webSearch
        case .asciiCapableNumberPad: return .asciiCapableNumberPad
        }
    }
}

extension InjectedTextInputAutoCapitalization {
    var render: TextInputAutocapitalization {
        switch self {
        case .never: return .never
        case .words: return .words
        case .sentences: return .sentences
        case .characters: return .characters
        }
    }
}

extension InjectedTextContentType {
    var render: UITextContentType {
        switch self {
        case .name: return .name
        case .givenName: return .givenName
        case .familyName: return .familyName
        case .nickname: return .nickname
        case .organizationName: return .organizationName
        case .jobTitle: return .jobTitle
        case .location: return .location
        case .fullStreetAddress: return .fullStreetAddress
        case .addressCity: return .addressCity
        case .addressState: return .addressState
        case .postalCode: return .postalCode
        case .countryName: return .countryName
        case .telephoneNumber: return .telephoneNumber
        case .emailAddress: return .emailAddress
        case .URL: return .URL
        case .creditCardNumber: return .creditCardNumber
        case .username: return .username
        case .password: return .password
        case .newPassword: return .newPassword
        case .oneTimeCode: return .oneTimeCode
        case .dateTime: return .dateTime
        case .flightNumber: return .flightNumber
        }
    }
}

extension InjectedRoundedCornerStyle {
    var render: RoundedCornerStyle {
        switch self {
        case .circular: return .circular
        case .continuous: return .continuous
        }
    }
}

extension InjectedButtonStyle {
    func apply<V: View>(to view: V) -> AnyView {
        switch self {
        case .automatic: return AnyView(view.buttonStyle(.automatic))
        case .bordered: return AnyView(view.buttonStyle(.bordered))
        case .borderedProminent: return AnyView(view.buttonStyle(.borderedProminent))
        case .borderless: return AnyView(view.buttonStyle(.borderless))
        case .plain: return AnyView(view.buttonStyle(.plain))
        }
    }
}

extension InjectedPickerStyle {
    func apply<V: View>(to view: V) -> AnyView {
        switch self {
        case .automatic: return AnyView(view.pickerStyle(.automatic))
        case .inline: return AnyView(view.pickerStyle(.inline))
        case .menu: return AnyView(view.pickerStyle(.menu))
        case .navigationLink: return AnyView(view.pickerStyle(.navigationLink))
        case .segmented: return AnyView(view.pickerStyle(.segmented))
        case .wheel: return AnyView(view.pickerStyle(.wheel))
        }
    }
}

extension InjectdDatePickerStyle {
    func apply<V: View>(to view: V) -> AnyView {
        switch self {
        case .automatic: return AnyView(view.datePickerStyle(.automatic))
        case .compact: return AnyView(view.datePickerStyle(.compact))
        case .graphical: return AnyView(view.datePickerStyle(.graphical))
        case .wheel: return AnyView(view.datePickerStyle(.wheel))
        }
    }
}
