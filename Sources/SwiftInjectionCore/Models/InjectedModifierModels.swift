//
//  InjectedModifierModels.swift
//  SwiftInjectionCore
//

import Foundation

public enum InjectedFontDesign: String, Codable, CaseIterable {
    case `default`, serif, rounded, monospaced
}

public enum InjectedFontWidth: String, Codable, CaseIterable {
    case compressed, condensed, standard, expanded
}

public enum InjectedTextLineStylePattern: String, Codable, CaseIterable {
    case solid, dot, dash, dashDot, dashDotDot
}

public enum InjectedTextTruncation: String, Codable, CaseIterable {
    case head, middle, tail
}

public enum InjectedBlendMode: String, Codable, CaseIterable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight,
         difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver, destinationOut,
         plusDarker, plusLighter
}

public enum InjectedTextAlignment: String, Codable, CaseIterable {
    case leading, center, trailing
}

public enum InjectedImageScale: String, Codable, CaseIterable {
    case small, medium, large
}

public enum InjectedAnimation: String, Codable, CaseIterable {
    case `default`, linear, easeIn, easeOut, easeInOut, spring, bouncy, smooth, snappy
}

public enum InjectedButtonStyle: String, Codable, CaseIterable {
    case automatic, bordered, borderedProminent, borderless, plain
}

public enum InjectedProgressViewStyle: String, Codable {
    case automatic, circular, linear
}

public enum InjectedPickerStyle: String, Codable, CaseIterable {
    case automatic, inline, menu, navigationLink, segmented, wheel
}

public enum InjectedSymbolRenderingMode: String, Codable, CaseIterable {
    case monochrome, hierarchical, multicolor, palette
}

public enum InjectedResizingMode: String, Codable, CaseIterable {
    case stretch, tile
}

public enum InjectedImageRenderingMode: String, Codable, CaseIterable {
    case original, template
}

public enum InjectdDatePickerStyle: String, Codable, CaseIterable {
    case automatic, compact, graphical, wheel
}

public enum InjectedVisbility: String, Codable, CaseIterable {
    case automatic, visible, hidden
}

public enum InjectedPopoverAttachmentAnchor: String, Codable {
    case bounds, top, bottom, leading, trailing, center
}

public enum InjectedEdge: String, Codable {
    case top, bottom, leading, trailing
}

public enum InjectedKeyboardType: String, Codable, CaseIterable {
    case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress,
         decimalPad, twitter, webSearch, asciiCapableNumberPad
}

public enum InjectedTextInputAutoCapitalization: String, Codable, CaseIterable {
    case never, words, sentences, characters
}

public enum InjectedTextContentType: String, Codable, CaseIterable {
    case name, givenName, familyName, nickname, organizationName, jobTitle, location, fullStreetAddress,
         addressCity, addressState, postalCode, countryName, telephoneNumber, emailAddress, URL,
         creditCardNumber, username, password, newPassword, oneTimeCode, dateTime, flightNumber
}

public enum InjectedRoundedCornerStyle: String, Codable {
    case circular, continuous
}
