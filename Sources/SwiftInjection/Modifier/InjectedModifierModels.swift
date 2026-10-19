//
//  InjectedModifierModels.swift
//
//
//  Created by Blake Osonduagwueki on 9/30/23.
//

import Foundation
import SwiftUI

public enum InjectedFontDesign: String, Codable {
    case `default`, serif, rounded, monospaced
    var render: Font.Design {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        }
    }
}

public enum InjectedFontWidth: String, Codable {
    case compressed, condensed, standard, expanded
    var render: Font.Width {
        switch self {
        case .compressed: return .compressed
        case .condensed: return .condensed
        case .standard: return .standard
        case .expanded: return .expanded
        }
    }
}

public enum InjectedTextLineStylePattern: String, Codable {
    case solid, dot, dash, dashDot, dashDotDot
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

public enum InjectedTextTruncation: String, Codable {
    case head, middle, tail
    var render: Text.TruncationMode {
        switch self {
        case .head: return .head
        case .middle: return .middle
        case .tail: return .tail
        }
    }
}

public enum InjectedBlendMode: String, Codable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight,
         difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver, destinationOut,
         plusDarker, plusLighter
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

public enum InjectedTextAlignment: String, Codable {
    case leading, center, trailing
    var render: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

public enum InjectedImageScale: String, Codable {
    case small, medium, large
    var render: Image.Scale {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }
}

public enum InjectedAnimation: String, Codable {
    case `default`, linear, easeIn, easeOut, easeInOut, spring, bouncy, smooth, snappy
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

public enum InjectedButtonStyle: String, Codable {
    case automatic, bordered, borderedProminent, borderless, plain
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

public enum InjectedProgressViewStyle: String, Codable {
    case automatic, circular, linear
}

public enum InjectedPickerStyle: String, Codable {
    case automatic, inline, menu, navigationLink, segmented, wheel
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

public enum InjectedSymbolRenderingMode: String, Codable {
    case monochrome, hierarchical, multicolor, palette
    var render: SymbolRenderingMode {
        switch self {
        case .monochrome: return .monochrome
        case .hierarchical: return .hierarchical
        case .multicolor: return .multicolor
        case .palette: return .palette
        }
    }
}

public enum InjectedResizingMode: String, Codable {
    case stretch, tile
    var render: Image.ResizingMode {
        switch self {
        case .stretch: return .stretch
        case .tile: return .tile
        }
    }
}

public enum InjectedImageRenderingMode: String, Codable {
    case original, template
    var render: Image.TemplateRenderingMode {
        switch self {
        case .original: return .original
        case .template: return .template
        }
    }
}

public enum InjectdDatePickerStyle: String, Codable {
    case automatic, compact, graphical, wheel
    func apply<V: View>(to view: V) -> AnyView {
        switch self {
        case .automatic: return AnyView(view.datePickerStyle(.automatic))
        case .compact: return AnyView(view.datePickerStyle(.compact))
        case .graphical: return AnyView(view.datePickerStyle(.graphical))
        case .wheel: return AnyView(view.datePickerStyle(.wheel))
        }
    }
}

public enum InjectedVisbility: String, Codable {
    case automatic, visible, hidden
    var render: Visibility {
        switch self {
        case .automatic: return .automatic
        case .visible: return .visible
        case .hidden: return .hidden
        }
    }
}

public enum InjectedPopoverAttachmentAnchor: String, Codable {
    case bounds, top, bottom, leading, trailing, center
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

public enum InjectedEdge: String, Codable {
    case top, bottom, leading, trailing
    var render: Edge {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

public enum InjectedKeyboardType: String, Codable {
    case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress,
         decimalPad, twitter, webSearch, asciiCapableNumberPad
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

public enum InjectedTextInputAutoCapitalization: String, Codable {
    case never, words, sentences, characters
    var render: TextInputAutocapitalization {
        switch self {
        case .never: return .never
        case .words: return .words
        case .sentences: return .sentences
        case .characters: return .characters
        }
    }
}

public enum InjectedTextContentType: String, Codable {
    case name, givenName, familyName, nickname, organizationName, jobTitle, location, fullStreetAddress,
         addressCity, addressState, postalCode, countryName, telephoneNumber, emailAddress, URL,
         creditCardNumber, username, password, newPassword, oneTimeCode, dateTime, flightNumber
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

public enum InjectedRoundedCornerStyle: String, Codable {
    case circular, continuous
    var render: RoundedCornerStyle {
        switch self {
        case .circular: return .circular
        case .continuous: return .continuous
        }
    }
}
