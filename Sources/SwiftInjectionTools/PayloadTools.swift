//
//  PayloadTools.swift
//  SwiftInjectionTools
//

import Foundation
import CryptoKit
import SwiftInjectionCore

/// The outcome of checking a payload file, as `swift-injection validate` reports it.
public struct ValidationReport: Equatable {
    public var isValid: Bool { error == nil }
    public var error: String?
    public var warnings: [String]
    public var schemaVersion: SchemaVersion?
    public var version: String?
    /// Whether a signature was checked (public keys were given).
    public var signatureChecked: Bool

    public var summary: String {
        if let error { return "✗ \(error)" }
        var parts = ["schema \(schemaVersion?.description ?? "?")"]
        if let version { parts.append("version \(version)") }
        parts.append(signatureChecked ? "signature verified" : "signature not checked")
        parts.append(warnings.count == 1 ? "1 warning" : "\(warnings.count) warnings")
        return "✓ valid (" + parts.joined(separator: ", ") + ")"
    }
}

public enum PayloadTools {
    /// Where `sign` writes and `PayloadLoader` fetches the signature: the payload path plus `.sig`.
    public static func signatureURL(for payload: URL) -> URL {
        payload.appendingPathExtension("sig")
    }

    /// Validates (unless `validate` is false) and signs `payload`, writing the detached signature.
    /// Returns the signature file's URL.
    @discardableResult
    public static func sign(payload: URL, key: Curve25519.Signing.PrivateKey, output: URL? = nil,
                            validate: Bool = true, runtime: SchemaVersion = .current) throws -> URL {
        guard let data = FileManager.default.contents(atPath: payload.path) else { throw ToolError.unreadable(payload.path) }
        if validate {
            do {
                _ = try PayloadValidator(runtimeVersion: runtime).validate(data, signature: nil)
            } catch {
                throw ToolError.invalidPayload("\(error)")
            }
        }
        let destination = output ?? signatureURL(for: payload)
        try PayloadSigner.signature(for: data, using: key).write(to: destination, options: .atomic)
        return destination
    }

    /// Checks a payload the way the app's loader will: signature (when public keys are given), size limits,
    /// decoding and schema version. `signature` defaults to the payload path plus `.sig`.
    public static func validate(payload: URL, signature: URL? = nil, publicKeys: [String] = [],
                                runtime: SchemaVersion = .current, limits: PayloadLimits = .default) -> ValidationReport {
        var report = ValidationReport(error: nil, warnings: [], schemaVersion: nil, version: nil, signatureChecked: !publicKeys.isEmpty)
        guard let data = FileManager.default.contents(atPath: payload.path) else {
            report.error = ToolError.unreadable(payload.path).description
            return report
        }
        do {
            var verifier: PayloadVerifier?
            var signatureData: Data?
            if !publicKeys.isEmpty {
                verifier = try PayloadVerifier(base64PublicKeys: publicKeys)
                let signaturePath = signature ?? signatureURL(for: payload)
                signatureData = FileManager.default.contents(atPath: signaturePath.path)
            }
            let validated = try PayloadValidator(verifier: verifier, runtimeVersion: runtime, limits: limits)
                .validate(data, signature: signatureData)
            report.warnings = validated.warnings
            report.schemaVersion = validated.payload.schemaVersion
            report.version = validated.payload.version
        } catch {
            report.error = "\(error)"
        }
        return report
    }
}
