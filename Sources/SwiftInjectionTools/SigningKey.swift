//
//  SigningKey.swift
//  SwiftInjectionTools
//

import Foundation
import CryptoKit
import SwiftInjectionCore

public enum ToolError: Error, Equatable, CustomStringConvertible {
    case fileExists(String)
    case unreadable(String)
    case invalidKey(String)
    case missingKey
    case invalidPayload(String)

    public var description: String {
        switch self {
        case .fileExists(let path): return "\(path) already exists (pass --force to overwrite)"
        case .unreadable(let path): return "Can't read \(path)"
        case .invalidKey(let reason): return "Invalid signing key: \(reason)"
        case .missingKey: return "No signing key: pass --key <file> or --key-env <VARIABLE>"
        case .invalidPayload(let reason): return "Refusing to sign an invalid payload: \(reason)"
        }
    }
}

/// Ed25519 signing keys. Files hold the base64 of the 32-byte raw private key.
public enum SigningKey {
    /// A new private key and its base64 public key (what apps pass to `PayloadVerifier`).
    public static func generate() -> (privateKey: Curve25519.Signing.PrivateKey, publicKey: String) {
        let key = Curve25519.Signing.PrivateKey()
        return (key, publicKey(of: key))
    }

    public static func publicKey(of key: Curve25519.Signing.PrivateKey) -> String {
        key.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Writes `key` to `url`, readable only by the current user. Refuses to overwrite unless `force`.
    public static func write(_ key: Curve25519.Signing.PrivateKey, to url: URL, force: Bool = false) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            guard force else { throw ToolError.fileExists(url.path) }
            try fileManager.removeItem(at: url)
        }
        let contents = Data((key.rawRepresentation.base64EncodedString() + "\n").utf8)
        guard fileManager.createFile(atPath: url.path, contents: contents, attributes: [.posixPermissions: 0o600]) else {
            throw ToolError.unreadable(url.path)
        }
    }

    public static func read(from url: URL) throws -> Curve25519.Signing.PrivateKey {
        guard let data = FileManager.default.contents(atPath: url.path) else { throw ToolError.unreadable(url.path) }
        return try parse(String(decoding: data, as: UTF8.self))
    }

    /// Parses the base64 key text (as stored in a key file or a CI secret).
    public static func parse(_ text: String) throws -> Curve25519.Signing.PrivateKey {
        guard let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ToolError.invalidKey("not base64")
        }
        do {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
        } catch {
            throw ToolError.invalidKey("expected a 32-byte Ed25519 private key")
        }
    }
}
