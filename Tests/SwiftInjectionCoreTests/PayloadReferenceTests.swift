import XCTest
@testable import SwiftInjectionCore

/// Keeps docs/PayloadReference.md in sync with the code: every example must decode cleanly, and everything the
/// runtime supports must be documented.
final class PayloadReferenceTests: XCTestCase {

    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.repository.appendingPathComponent(path), encoding: .utf8)
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
            String(text[Range($0.range(at: 1), in: text)!])
        }
    }

    private var reference: String { get throws { try read("docs/PayloadReference.md") } }

    /// The section of the reference between `## title` and the next `## ` heading.
    private func section(_ title: String) throws -> String {
        let text = try reference
        let start = try XCTUnwrap(text.range(of: "\n## \(title)\n"), "missing section \(title)")
        let rest = text[start.upperBound...]
        return String(rest[..<(rest.range(of: "\n## ")?.lowerBound ?? rest.endIndex)])
    }

    // MARK: examples

    func testEveryExampleDecodesWithoutWarnings() throws {
        let blocks = matches("```json\n(.*?)```", in: try reference)
        XCTAssertGreaterThan(blocks.count, 50)
        for block in blocks {
            XCTAssertNil(decodeError(block), "Example doesn't decode cleanly:\n\(block)\n\(decodeError(block) ?? "")")
        }
    }

    /// Tries each payload type an example can be; returns why none of them decoded cleanly, or nil.
    private func decodeError(_ json: String) -> String? {
        func attempt<T: Decodable>(_ type: T.Type) -> String? {
            let warnings = PayloadWarnings()
            let decoder = JSONDecoder()
            decoder.userInfo[.payloadWarnings] = warnings
            do {
                _ = try decoder.decode(type, from: Data(json.utf8))
                return warnings.messages.isEmpty ? nil : "\(T.self): \(warnings.messages)"
            } catch {
                return "\(T.self): \(PayloadValidator.describe(error))"
            }
        }
        var errors: [String] = []
        // Expressions last: almost any JSON literal is one.
        for result in [attempt(InjectedPayload.self), attempt(InjectedView.self), attempt([InjectedModifier].self),
                       attempt(InjectedModifier.self), attempt([InjectedAction].self), attempt(InjectedAction.self),
                       attempt(InjectedExpression.self)] {
            guard let result else { return nil }
            errors.append(result)
        }
        return errors.joined(separator: "\n")
    }

    // MARK: coverage

    func testEveryComponentIsDocumented() throws {
        // The decoder's own list of component names is the source of truth.
        let source = try read("Sources/SwiftInjectionCore/Views/InjectedView.swift")
        let components = Set(matches(#"case "(\w+)": self ="#, in: source))
        XCTAssertGreaterThan(components.count, 40)
        let documented = Set(matches("\n### `(\\w+)`\n", in: try section("Components")))
        XCTAssertEqual(components.subtracting(documented).sorted(), [], "Undocumented components")
        XCTAssertEqual(documented.subtracting(components).sorted(), [], "Documented components that don't exist")
    }

    func testEveryModifierIsDocumented() throws {
        let documented = Set(matches(#"\| ((?:`\w+`(?:, )?)+) \|"#, in: try section("Modifiers"))
            .flatMap { row in matches("`(\\w+)`", in: row) })
        XCTAssertEqual(InjectedModifier.knownNames.subtracting(documented).sorted(), [], "Undocumented modifiers")
    }

    func testEveryOperatorIsDocumented() throws {
        let documented = Set(matches(#"\n\| `(\w+)` \|"#, in: try section("Expression operators")))
        let operators = Set(InjectedExpression.Operator.allCases.map(\.rawValue))
        XCTAssertEqual(operators.subtracting(documented).sorted(), [], "Undocumented operators")
        XCTAssertEqual(documented.subtracting(operators).sorted(), [], "Documented operators that don't exist")
    }

    func testEveryActionIsDocumented() throws {
        // The decoder's table of action shapes is the source of truth.
        let source = try read("Sources/SwiftInjectionCore/Actions/InjectedAction.swift")
        let shapes = try XCTUnwrap(matches(#"shapes: \[String: Set<String>\] = \[(.*?)\n    \]"#, in: source).first)
        let actions = Set(matches(#""(\w+)": \["#, in: shapes))
        XCTAssertEqual(actions, ["set", "if", "delay", "call"])
        let documented = Set(matches("\n### `(\\w+)`\n", in: try section("Actions")))
        XCTAssertEqual(actions, documented)
    }

    func testEveryOptionValueIsListed() throws {
        let text = try reference
        func check<T: CaseIterable & RawRepresentable>(_ type: T.Type) where T.RawValue == String {
            for value in T.allCases.map(\.rawValue) where !text.contains("`\(value)`") {
                XCTFail("\(T.self).\(value) isn't documented")
            }
        }
        check(InjectedSystemFont.self); check(InjectedFontWeight.self); check(InjectedHorizontalAlignment.self)
        check(InjectedVerticalAlignment.self); check(InjectedAlignment.self); check(InjectedEdgeSet.self)
        check(InjectedAnimation.self); check(InjectedBlendMode.self); check(InjectedKeyboardType.self)
        check(InjectedTextContentType.self); check(InjectedFontDesign.self); check(InjectedFontWidth.self)
        check(InjectedTextLineStylePattern.self); check(InjectedTextTruncation.self); check(InjectedTextAlignment.self)
        check(InjectedSymbolRenderingMode.self); check(InjectedImageScale.self); check(InjectedButtonStyle.self)
        check(InjectedPickerStyle.self); check(InjectdDatePickerStyle.self); check(InjectedTextInputAutoCapitalization.self)
        check(InjectedVisbility.self); check(InjectedResizingMode.self); check(InjectedImageRenderingMode.self)
        check(InjectedTabViewStyle.self); check(InjectedIndexDisplayMode.self); check(InjectedContentMode.self)
    }
}
