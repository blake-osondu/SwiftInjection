//
//  PayloadDecoding.swift
//  SwiftInjection
//

import Foundation

/// Collects non-fatal problems found while decoding (unknown components and modifiers).
final class PayloadWarnings {
    var messages: [String] = []
}

extension CodingUserInfoKey {
    static let payloadWarnings = CodingUserInfoKey(rawValue: "SwiftInjection.payloadWarnings")!
}

extension Decoder {
    func reportPayloadWarning(_ message: String) {
        (userInfo[.payloadWarnings] as? PayloadWarnings)?.messages.append(message)
    }

    var codingPathDescription: String {
        codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
    }
}

/// Modifier lists skip modifiers this runtime doesn't know (reporting a warning) instead of rejecting the
/// payload, so newer payloads degrade gracefully. Known modifiers with bad arguments still fail.
extension KeyedDecodingContainer {
    public func decode(_ type: OrEmpty<[InjectedModifier]>.Type, forKey key: Key) throws -> OrEmpty<[InjectedModifier]> {
        guard let elements = try decodeIfPresent([LenientModifier].self, forKey: key) else { return OrEmpty() }
        return OrEmpty(wrappedValue: elements.compactMap(\.modifier))
    }
}

private struct LenientModifier: Decodable {
    let modifier: InjectedModifier?

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let keys = try decoder.container(keyedBy: AnyKey.self).allKeys.map(\.stringValue)
        if keys.count == 1, let name = keys.first, !InjectedModifier.knownNames.contains(name) {
            decoder.reportPayloadWarning("Skipped unknown modifier '\(name)' at \(decoder.codingPathDescription)")
            modifier = nil
        } else {
            modifier = try InjectedModifier(from: decoder)
        }
    }
}

extension InjectedModifier {
    /// Every modifier name this runtime understands (the JSON key of each case).
    static let knownNames: Set<String> = [
        "systemFont", "font", "fontWeight", "fontDesign", "fontWidth", "bold", "italic", "monospaced",
        "monospacedDigit", "kerning", "tracking", "strikethrough", "underline", "lineLimit", "truncationMode",
        "multilineTextAlignment", "minimumScaleFactor", "frame", "padding", "position", "layoutPriority",
        "fixedSize", "ignoresSafeArea", "foregroundColor", "background", "cornerRadius", "border", "opacity",
        "shadow", "blur", "brightness", "blendMode", "colorInvert", "colorMultiply", "symbolRenderingMode",
        "imageScale", "unredacted", "animation", "sheet", "fullScreenCover", "popover", "alert",
        "confirmationDialog", "disabled", "buttonStyle", "pickerStyle", "datePickerStyle", "tag", "badge",
        "tabItem", "keyboardType", "autocorrectionDisabled", "textInputAutocapitalization", "textContentType",
        "onAppear", "onDisappear", "onTapGesture", "onChange", "onSubmit", "antialiased", "resizable",
        "renderingMode", "path",
    ]
}
