//
//  PayloadSignature.swift
//  SwiftInjection
//

import Foundation
import CryptoKit

/// Verifies Ed25519 signatures over a payload's exact bytes. Accepts any of several public keys,
/// so a new key can be shipped in the app before payloads start being signed with it.
public struct PayloadVerifier {
    public let publicKeys: [Curve25519.Signing.PublicKey]

    public init(publicKeys: [Curve25519.Signing.PublicKey]) {
        self.publicKeys = publicKeys
    }

    /// Keys as base64 of their 32-byte raw representation.
    public init(base64PublicKeys: [String]) throws {
        self.publicKeys = try base64PublicKeys.map { key in
            guard let data = Data(base64Encoded: key) else { throw PayloadError.invalid("Public key isn't base64") }
            return try Curve25519.Signing.PublicKey(rawRepresentation: data)
        }
    }

    /// `signature` is the base64 text served alongside the payload (surrounding whitespace is ignored).
    public func verify(_ payload: Data, signature: Data) throws {
        let text = String(decoding: signature, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: text) else { throw PayloadError.signatureInvalid }
        guard publicKeys.contains(where: { $0.isValidSignature(raw, for: payload) }) else {
            throw PayloadError.signatureInvalid
        }
    }
}

/// Produces the detached signature file content for a payload (for publishing tools and tests).
public enum PayloadSigner {
    public static func signature(for payload: Data, using key: Curve25519.Signing.PrivateKey) throws -> Data {
        Data(try key.signature(for: payload).base64EncodedString().utf8)
    }
}
