import XCTest
import CryptoKit
@testable import SwiftInjectionCore

/// Exercises the payload model with SwiftInjectionCore alone (no SwiftUI), as the CLI and CI will.
final class CorePayloadTests: XCTestCase {

    static let payload = Data(#"""
    {
      "schemaVersion": "1.0",
      "version": "core-test",
      "state": { "count": 0, "todos": [ { "title": "Milk", "done": false } ] },
      "scripts": { "double": "(n) => n * 2" },
      "body": { "vStack": { "spacing": 8, "modifiers": [{ "padding": { "length": 12 } }], "children": [
        { "text": { "value": { "format": ["Tapped {0} times", { "var": "count" }] } } },
        { "button": { "title": "Tap", "action": [ { "set": "count", "to": { "add": [{ "var": "count" }, 1] } } ] } },
        { "if": { "condition": { "gte": [{ "var": "count" }, 10] }, "then": { "text": { "value": "Double digits!" } } } },
        { "forEach": { "items": "todos", "content": { "field": { "text": "item.title", "title": "To-do" } } } },
        { "ref": "footer" }
      ]}},
      "views": { "footer": { "text": { "value": { "count": { "var": "todos" } } } } }
    }
    """#.utf8)

    func testValidatesAndRoundTripsTheEndToEndPayload() throws {
        let validated = try PayloadValidator().validate(Self.payload, signature: nil)
        XCTAssertEqual(validated.warnings, [])
        XCTAssertEqual(validated.payload.schemaVersion, .current)
        XCTAssertEqual(validated.payload.views.keys.sorted(), ["footer"])
        XCTAssertEqual(validated.payload.scripts.keys.sorted(), ["double"])

        guard case let .vStack(stack) = validated.payload.body else { return XCTFail() }
        XCTAssertEqual(stack.children.count, 5)
        XCTAssertEqual(stack.modifiers.count, 1)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys  // dictionary order is otherwise unspecified
        let reencoded = try encoder.encode(validated.payload)
        let again = try PayloadValidator().validate(reencoded, signature: nil)
        XCTAssertEqual(try encoder.encode(again.payload), reencoded)
    }

    func testSignsAndVerifiesWithCoreAlone() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signature = try PayloadSigner.signature(for: Self.payload, using: key)
        let validator = PayloadValidator(verifier: PayloadVerifier(publicKeys: [key.publicKey]))
        XCTAssertNoThrow(try validator.validate(Self.payload, signature: signature))
        XCTAssertThrowsError(try validator.validate(Self.payload + Data(" ".utf8), signature: signature)) {
            XCTAssertEqual($0 as? PayloadError, .signatureInvalid)
        }
    }

    func testEvaluatesExpressionsAndActionsShapes() throws {
        let payload = try PayloadValidator().validate(Self.payload, signature: nil).payload
        guard case let .vStack(stack) = payload.body, case let .text(text) = stack.children[0] else { return XCTFail() }
        XCTAssertEqual(try ExpressionEvaluator().evaluate(text.value, in: payload.state), "Tapped 0 times")

        guard case let .button(button) = stack.children[1], case let .set(path, to)? = button.action.first else { return XCTFail() }
        XCTAssertEqual(path, "count")
        XCTAssertEqual(try ExpressionEvaluator().evaluate(to, in: payload.state), 1)
    }
}
