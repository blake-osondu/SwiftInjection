//
//  InjectedModifierModels.swift
//  SwiftInjectionCore
//

import Foundation

public enum InjectedFontDesign: String, Codable {
    case `default`, serif, rounded, monospaced
}

public enum InjectedFontWidth: String, Codable {
    case compressed, condensed, standard, expanded
}

public enum InjectedTextLineStylePattern: String, Codable {
    case solid, dot, dash, dashDot, dashDotDot
}

public enum InjectedTextTruncation: String, Codable {
    case head, middle, tail
}

public enum InjectedBlendMode: String, Codable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight,
         difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver, destinationOut,
         plusDarker, plusLighter
}

public enum InjectedTextAlignment: String, Codable {
    case leading, center, trailing
}

public enum InjectedImageScale: String, Codable {
    case small, medium, large
}

public enum InjectedAnimation: String, Codable {
    case `default`, linear, easeIn, easeOut, easeInOut, spring, bouncy, smooth, snappy
}

public enum InjectedButtonStyle: String, Codable {
    case automatic, bordered, borderedProminent, borderless, plain
}

public enum InjectedProgressViewStyle: String, Codable {
    case automatic, circular, linear
}

public enum InjectedPickerStyle: String, Codable {
    case automatic, inline, menu, navigationLink, segmented, wheel
}

public enum InjectedSymbolRenderingMode: String, Codable {
    case monochrome, hierarchical, multicolor, palette
}

public enum InjectedResizingMode: String, Codable {
    case stretch, tile
}

public enum InjectedImageRenderingMode: String, Codable {
    case original, template
}

public enum InjectdDatePickerStyle: String, Codable {
    case automatic, compact, graphical, wheel
}

public enum InjectedVisbility: String, Codable {
    case automatic, visible, hidden
}

public enum InjectedPopoverAttachmentAnchor: String, Codable {
    case bounds, top, bottom, leading, trailing, center
}

public enum InjectedEdge: String, Codable {
    case top, bottom, leading, trailing
}

public enum InjectedKeyboardType: String, Codable {
    case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress,
         decimalPad, twitter, webSearch, asciiCapableNumberPad
}

public enum InjectedTextInputAutoCapitalization: String, Codable {
    case never, words, sentences, characters
}

public enum InjectedTextContentType: String, Codable {
    case name, givenName, familyName, nickname, organizationName, jobTitle, location, fullStreetAddress,
         addressCity, addressState, postalCode, countryName, telephoneNumber, emailAddress, URL,
         creditCardNumber, username, password, newPassword, oneTimeCode, dateTime, flightNumber
}

public enum InjectedRoundedCornerStyle: String, Codable {
    case circular, continuous
}
