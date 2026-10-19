//
//  SwiftInjectionCommand.swift
//  swift-injection
//

import Foundation
import ArgumentParser
import CryptoKit
import SwiftInjectionCore
import SwiftInjectionTools

@main
struct SwiftInjectionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-injection",
        abstract: "Create signing keys, and sign and validate SwiftInjection payloads.",
        version: "0.1.0 (schema \(SchemaVersion.current))",
        subcommands: [Keygen.self, Sign.self, Validate.self])
}

struct Keygen: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create an Ed25519 signing key.",
        discussion: """
        Writes the private key (readable only by you) and prints the public key to pass to \
        PayloadVerifier(base64PublicKeys:) in your app. Keep the private key off your payload server; \
        in CI, store its contents as a secret and use `sign --key-env`.
        """)

    @Option(name: .shortAndLong, help: "Where to write the private key.")
    var out: String

    @Flag(help: "Overwrite an existing key file.")
    var force = false

    func run() throws {
        let (key, publicKey) = SigningKey.generate()
        try SigningKey.write(key, to: URL(fileURLWithPath: out), force: force)
        FileHandle.standardError.write(Data("Wrote private key to \(out). Public key:\n".utf8))
        print(publicKey)
    }
}

struct Sign: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate a payload and write its detached signature (<payload>.sig).")

    @Argument(help: "The payload JSON file.")
    var payload: String

    @Option(help: "Private key file from `keygen`.")
    var key: String?

    @Option(name: .customLong("key-env"), help: "Environment variable holding the private key (for CI secrets).")
    var keyEnvironment: String?

    @Option(name: .shortAndLong, help: "Where to write the signature (default: <payload>.sig).")
    var output: String?

    @Flag(name: .customLong("no-validate"), help: "Sign without validating first.")
    var skipValidation = false

    func run() throws {
        let signingKey: SigningKeyInput
        if let key {
            signingKey = .file(key)
        } else if let keyEnvironment {
            signingKey = .environment(keyEnvironment)
        } else {
            throw ToolError.missingKey
        }
        let written = try PayloadTools.sign(payload: URL(fileURLWithPath: payload), key: signingKey.load(),
                                            output: output.map(URL.init(fileURLWithPath:)),
                                            validate: !skipValidation)
        print("Signed \(payload) → \(written.path)")
    }

    enum SigningKeyInput {
        case file(String)
        case environment(String)

        func load() throws -> Curve25519.Signing.PrivateKey {
            switch self {
            case .file(let path):
                return try SigningKey.read(from: URL(fileURLWithPath: path))
            case .environment(let name):
                guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
                    throw ToolError.invalidKey("environment variable \(name) is empty or unset")
                }
                return try SigningKey.parse(value)
            }
        }
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check a payload the way the app will load it.",
        discussion: "Exits with status 1 if the payload is invalid, so it can gate CI.")

    @Argument(help: "The payload JSON file.")
    var payload: String

    @Option(name: .customLong("public-key"), help: "Base64 public key to verify the signature against (repeatable).")
    var publicKeys: [String] = []

    @Option(help: "Signature file (default: <payload>.sig). Only used with --public-key.")
    var signature: String?

    @Option(help: "Runtime schema version to check against, e.g. 1.0 (default: this tool's).")
    var schema: String?

    func run() throws {
        var runtime = SchemaVersion.current
        if let schema {
            guard let parsed = SchemaVersion(schema) else { throw ValidationError("--schema must be major.minor, e.g. 1.0") }
            runtime = parsed
        }
        let report = PayloadTools.validate(payload: URL(fileURLWithPath: payload),
                                           signature: signature.map(URL.init(fileURLWithPath:)),
                                           publicKeys: publicKeys, runtime: runtime)
        for warning in report.warnings {
            print("warning: \(warning)")
        }
        print(report.summary)
        if !report.isValid { throw ExitCode.failure }
    }
}
