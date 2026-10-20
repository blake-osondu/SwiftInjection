import XCTest
import CryptoKit
@testable import SwiftInjectionCore
@testable import SwiftInjectionTools

final class PayloadToolsTests: XCTestCase {
    var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func file(_ name: String, _ contents: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private let validPayload = #"{"schemaVersion": "1.0", "version": "7", "body": {"text": {"value": "Hi", "modifiers": [{"sparkle": {}}]}}}"#

    // MARK: keys

    func testKeyRoundTripAndPermissions() throws {
        let (key, publicKey) = SigningKey.generate()
        let url = directory.appendingPathComponent("release.key")
        try SigningKey.write(key, to: url)

        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
        XCTAssertEqual(try SigningKey.read(from: url).rawRepresentation, key.rawRepresentation)
        XCTAssertEqual(SigningKey.publicKey(of: try SigningKey.read(from: url)), publicKey)
        XCTAssertNoThrow(try PayloadVerifier(base64PublicKeys: [publicKey]))
    }

    func testKeyWriteRefusesToOverwriteUnlessForced() throws {
        let url = directory.appendingPathComponent("release.key")
        let first = SigningKey.generate().privateKey
        try SigningKey.write(first, to: url)
        XCTAssertThrowsError(try SigningKey.write(SigningKey.generate().privateKey, to: url)) {
            XCTAssertEqual($0 as? ToolError, .fileExists(url.path))
        }
        XCTAssertEqual(try SigningKey.read(from: url).rawRepresentation, first.rawRepresentation)

        let replacement = SigningKey.generate().privateKey
        try SigningKey.write(replacement, to: url, force: true)
        XCTAssertEqual(try SigningKey.read(from: url).rawRepresentation, replacement.rawRepresentation)
    }

    func testParseRejectsBadKeys() {
        XCTAssertThrowsError(try SigningKey.parse("not base64!")) { XCTAssertEqual($0 as? ToolError, .invalidKey("not base64")) }
        XCTAssertThrowsError(try SigningKey.parse(Data([1, 2, 3]).base64EncodedString())) {
            XCTAssertEqual($0 as? ToolError, .invalidKey("expected a 32-byte Ed25519 private key"))
        }
        let key = SigningKey.generate().privateKey
        XCTAssertNoThrow(try SigningKey.parse("  \(key.rawRepresentation.base64EncodedString())\n"))
    }

    // MARK: sign → the runtime's verifier

    func testSignedPayloadVerifiesWithTheRuntimeVerifier() throws {
        let payload = try file("home.json", validPayload)
        let (key, publicKey) = SigningKey.generate()
        let signatureURL = try PayloadTools.sign(payload: payload, key: key)
        XCTAssertEqual(signatureURL, payload.appendingPathExtension("sig"))

        let validator = PayloadValidator(verifier: try PayloadVerifier(base64PublicKeys: [publicKey]))
        XCTAssertNoThrow(try validator.validate(try Data(contentsOf: payload), signature: try Data(contentsOf: signatureURL)))
    }

    func testSignRefusesInvalidPayloadsUnlessValidationIsSkipped() throws {
        let payload = try file("bad.json", #"{"body": {"text": {}}}"#)
        let key = SigningKey.generate().privateKey
        XCTAssertThrowsError(try PayloadTools.sign(payload: payload, key: key)) {
            guard case .invalidPayload? = $0 as? ToolError else { return XCTFail("\($0)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: payload.appendingPathExtension("sig").path))

        XCTAssertNoThrow(try PayloadTools.sign(payload: payload, key: key, validate: false))
    }

    // MARK: validate

    func testValidateReportsWarningsAndSummary() throws {
        let report = PayloadTools.validate(payload: try file("home.json", validPayload))
        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.version, "7")
        XCTAssertEqual(report.warnings, ["Skipped unknown modifier 'sparkle' at .body.text.modifiers[0]"])
        XCTAssertEqual(report.summary, "✓ valid (schema 1.0, version 7, signature not checked, 1 warning)")
    }

    func testValidateReportsTheErrorPath() throws {
        let report = PayloadTools.validate(payload: try file("bad.json", #"{"schemaVersion": "1.0", "body": {"vStack": {"children": [{"text": {}}]}}}"#))
        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.summary, #"✗ Invalid payload: body.vStack.children[0].text: missing key "value""#)
    }

    func testValidateChecksSignaturesWhenKeysAreGiven() throws {
        let payload = try file("home.json", validPayload)
        let (key, publicKey) = SigningKey.generate()
        try PayloadTools.sign(payload: payload, key: key)

        let good = PayloadTools.validate(payload: payload, publicKeys: [publicKey])
        XCTAssertTrue(good.isValid)
        XCTAssertTrue(good.summary.contains("signature verified"), good.summary)

        let otherKey = SigningKey.generate().publicKey
        XCTAssertEqual(PayloadTools.validate(payload: payload, publicKeys: [otherKey]).error, PayloadError.signatureInvalid.description)

        try FileManager.default.removeItem(at: payload.appendingPathExtension("sig"))
        XCTAssertEqual(PayloadTools.validate(payload: payload, publicKeys: [publicKey]).error, PayloadError.signatureMissing.description)
    }

    func testValidateChecksAgainstARuntimeSchema() throws {
        let payload = try file("new.json", #"{"schemaVersion": "1.3", "body": {"empty": {}}}"#)
        XCTAssertFalse(PayloadTools.validate(payload: payload, runtime: SchemaVersion(major: 1, minor: 2)).isValid)
        XCTAssertTrue(PayloadTools.validate(payload: payload, runtime: SchemaVersion(major: 1, minor: 3)).isValid)
    }
}
