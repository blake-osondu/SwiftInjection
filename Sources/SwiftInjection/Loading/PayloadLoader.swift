//
//  PayloadLoader.swift
//  SwiftInjection
//

import Foundation
import CryptoKit
import SwiftInjectionCore

/// Loads a screen's payload from a URL, falling back to the last good cached copy and then to a payload
/// bundled with the app. Every source is validated (signature, schema version, decoding) before use, and
/// only a valid remote payload replaces the cache.
///
/// ```swift
/// let loader = PayloadLoader(configuration: .init(
///     url: URL(string: "https://cdn.example.com/screens/home.json")!,
///     bundled: Bundle.main.url(forResource: "home", withExtension: "json"),
///     verifier: try PayloadVerifier(base64PublicKeys: ["…"])))
/// let loaded = try await loader.load()
/// ```
public final class PayloadLoader {
    public struct Configuration {
        public var url: URL
        /// Where the detached signature is served. Defaults to `url` + `.sig`.
        public var signatureURL: URL?
        /// A payload shipped in the app, used when the network and cache both fail. It's trusted without a
        /// signature because it's covered by the app's code signature.
        public var bundled: URL?
        /// When set, remote and cached payloads must carry a valid signature.
        public var verifier: PayloadVerifier?
        public var cacheDirectory: URL
        public var session: URLSession
        public var runtimeVersion: SchemaVersion

        public init(url: URL, signatureURL: URL? = nil, bundled: URL? = nil, verifier: PayloadVerifier? = nil,
                    cacheDirectory: URL? = nil, session: URLSession = .shared, runtimeVersion: SchemaVersion = .current) {
            self.url = url
            self.signatureURL = signatureURL
            self.bundled = bundled
            self.verifier = verifier
            self.cacheDirectory = cacheDirectory
                ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SwiftInjection", isDirectory: true)
            self.session = session
            self.runtimeVersion = runtimeVersion
        }

        var resolvedSignatureURL: URL {
            signatureURL ?? url.appendingPathExtension("sig")
        }
    }

    public enum Source: String, Equatable {
        case remote, cache, bundle
    }

    public struct Loaded {
        public let payload: InjectedPayload
        public let source: Source
        /// Non-fatal problems in the payload that was used (skipped unknown components/modifiers).
        public let warnings: [String]
        /// Why earlier sources were skipped, e.g. a network error before falling back to the cache.
        public let skipped: [PayloadError]
    }

    public let configuration: Configuration
    private let validator: PayloadValidator

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.validator = PayloadValidator(verifier: configuration.verifier, runtimeVersion: configuration.runtimeVersion)
    }

    /// Tries the network, then the cache, then the bundled payload.
    public func load() async throws -> Loaded {
        var skipped: [PayloadError] = []
        do {
            return try await loadRemote()
        } catch {
            skipped.append(Self.payloadError(error))
        }
        return try loadLocal(skipped: skipped)
    }

    /// The cache, then the bundled payload, without touching the network. Use it to show something
    /// immediately, then call `load()` to pick up updates.
    public func loadLocal() throws -> Loaded {
        try loadLocal(skipped: [])
    }

    /// Fetches and validates the remote payload, and caches it on success.
    public func loadRemote() async throws -> Loaded {
        let data = try await fetch(configuration.url)
        let signature = configuration.verifier == nil ? nil : try await fetch(configuration.resolvedSignatureURL)
        let validated = try validator.validate(data, signature: signature)
        try? writeCache(data, signature: signature)
        return Loaded(payload: validated.payload, source: .remote, warnings: validated.warnings, skipped: [])
    }

    // MARK: - Local sources

    private func loadLocal(skipped: [PayloadError]) throws -> Loaded {
        var skipped = skipped
        do {
            let (data, signature) = try readCache()
            let validated = try validator.validate(data, signature: signature)
            return Loaded(payload: validated.payload, source: .cache, warnings: validated.warnings, skipped: skipped)
        } catch {
            skipped.append(Self.payloadError(error))
        }

        if let bundled = configuration.bundled {
            do {
                let validated = try validator.validate(try Data(contentsOf: bundled), signature: nil, requireSignature: false)
                return Loaded(payload: validated.payload, source: .bundle, warnings: validated.warnings, skipped: skipped)
            } catch {
                skipped.append(Self.payloadError(error))
            }
        } else {
            skipped.append(.invalid("No bundled payload configured"))
        }
        throw PayloadError.noPayloadAvailable(skipped.map(\.description))
    }

    // MARK: - Cache

    private var cacheKey: String {
        SHA256.hash(data: Data(configuration.url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    var cachedPayloadURL: URL { configuration.cacheDirectory.appendingPathComponent("\(cacheKey).json") }
    var cachedSignatureURL: URL { configuration.cacheDirectory.appendingPathComponent("\(cacheKey).json.sig") }

    private func readCache() throws -> (Data, Data?) {
        guard FileManager.default.fileExists(atPath: cachedPayloadURL.path) else {
            throw PayloadError.invalid("No cached payload")
        }
        let data = try Data(contentsOf: cachedPayloadURL)
        let signature = try? Data(contentsOf: cachedSignatureURL)
        return (data, signature)
    }

    private func writeCache(_ data: Data, signature: Data?) throws {
        try FileManager.default.createDirectory(at: configuration.cacheDirectory, withIntermediateDirectories: true)
        if let signature {
            try signature.write(to: cachedSignatureURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: cachedSignatureURL)
        }
        try data.write(to: cachedPayloadURL, options: .atomic)
    }

    // MARK: - Network

    private func fetch(_ url: URL) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await configuration.session.data(from: url)
        } catch {
            throw PayloadError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PayloadError.httpStatus(http.statusCode)
        }
        return data
    }

    private static func payloadError(_ error: Error) -> PayloadError {
        error as? PayloadError ?? .invalid(PayloadValidator.describe(error))
    }
}
