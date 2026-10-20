//
//  SwiftInjectionCommand.swift
//  swift-injection
//

import Foundation
import ArgumentParser
import CryptoKit
import SwiftInjectionCore
import SwiftInjectionTools
import SwiftInjectionCompiler

@main
struct SwiftInjectionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-injection",
        abstract: "Compile SwiftUI screens to payloads, create signing keys, and sign and validate payloads.",
        version: "0.1.0 (schema \(SchemaVersion.current))",
        subcommands: [Compile.self, Keygen.self, Sign.self, Validate.self])
}

struct Compile: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Compile a SwiftUI screen (a supported subset of Swift) to a payload.",
        discussion: """
        The source is ordinary SwiftUI: one `struct …: View` with @State properties and a body. \
        Unsupported Swift is reported as file:line:column errors and nothing is written.
        """)

    @Argument(help: "The Swift file to compile.")
    var source: String

    @Option(name: .shortAndLong, help: "Where to write the payload (default: the source path with .json).")
    var output: String?

    @Option(name: .customLong("payload-version"), help: "The payload's `version` identifier, e.g. a build number.")
    var payloadVersion: String?

    @Option(help: "JavaScript for script(…) / runScript(…) calls (default: <source>.scripts.js if it exists).")
    var scripts: String?

    @Option(help: "Comma-separated names of the app's own views (e.g. design-system components) to compile as custom components.")
    var components: String?

    @Flag(help: "Recompile whenever the source or script file changes.")
    var watch = false

    func run() throws {
        let sourceURL = URL(fileURLWithPath: source)
        let scriptsURL = scripts.map(URL.init(fileURLWithPath:))
            ?? sourceURL.deletingPathExtension().appendingPathExtension("scripts.js")
        let destination = output.map(URL.init(fileURLWithPath:)) ?? sourceURL.deletingPathExtension().appendingPathExtension("json")

        // Line-buffer stdout so progress shows up immediately when piped (a watcher never exits normally).
        setvbuf(stdout, nil, _IOLBF, 0)
        guard watch else {
            if !compileOnce(sourceURL, scriptsURL, destination) { throw ExitCode.failure }
            return
        }
        print("Watching \(source) (Ctrl-C to stop)")
        var lastChange: Date?
        while true {
            let change = [sourceURL, scriptsURL].compactMap(modificationDate).max()
            if change != lastChange {
                lastChange = change
                _ = compileOnce(sourceURL, scriptsURL, destination)
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Compiles and writes the payload; prints diagnostics. Returns false if there were errors.
    private func compileOnce(_ sourceURL: URL, _ scriptsURL: URL, _ destination: URL) -> Bool {
        guard let data = FileManager.default.contents(atPath: sourceURL.path) else {
            FileHandle.standardError.write(Data("\(ToolError.unreadable(source))\n".utf8))
            return false
        }
        if let scripts, FileManager.default.contents(atPath: scriptsURL.path) == nil {
            FileHandle.standardError.write(Data("\(ToolError.unreadable(scripts))\n".utf8))
            return false
        }
        let scriptSource = FileManager.default.contents(atPath: scriptsURL.path).map { String(decoding: $0, as: UTF8.self) }
        let result = SwiftUICompiler.compile(source: String(decoding: data, as: UTF8.self), fileName: source,
                                             version: payloadVersion, scripts: scriptSource,
                                             components: Set((components ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }))
        for diagnostic in result.diagnostics {
            FileHandle.standardError.write(Data("\(diagnostic)\n".utf8))
        }
        do {
            guard let json = try result.json() else {
                let count = result.errors.count
                FileHandle.standardError.write(Data("\(count) error\(count == 1 ? "" : "s"); no payload written.\n".utf8))
                return false
            }
            try json.write(to: destination, options: .atomic)
            print("Compiled \(source) → \(destination.path)")
            if !result.hostFunctions.isEmpty {
                print("Host functions the app must register: \(result.hostFunctions.joined(separator: ", "))")
            }
            if !result.components.isEmpty {
                print("Components the app must register: \(result.components.joined(separator: ", "))")
            }
            return true
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            return false
        }
    }
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
