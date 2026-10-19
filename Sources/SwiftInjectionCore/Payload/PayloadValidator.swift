//
//  PayloadValidator.swift
//  SwiftInjection
//

import Foundation

/// A payload that passed validation, plus any non-fatal warnings (skipped unknown components/modifiers).
public struct ValidatedPayload {
    public let payload: InjectedPayload
    public let warnings: [String]
}

/// Checks a payload's signature (when a verifier is configured), decodes it, and checks its schema version.
public struct PayloadValidator {
    public var verifier: PayloadVerifier?
    public var runtimeVersion: SchemaVersion

    public init(verifier: PayloadVerifier? = nil, runtimeVersion: SchemaVersion = .current) {
        self.verifier = verifier
        self.runtimeVersion = runtimeVersion
    }

    /// `signature` is required when a verifier is configured; pass `requireSignature: false` for
    /// payloads that are trusted by other means (e.g. bundled in the signed app).
    public func validate(_ data: Data, signature: Data?, requireSignature: Bool = true) throws -> ValidatedPayload {
        if let verifier, requireSignature {
            guard let signature else { throw PayloadError.signatureMissing }
            try verifier.verify(data, signature: signature)
        }

        let warnings = PayloadWarnings()
        let decoder = JSONDecoder()
        decoder.userInfo[.payloadWarnings] = warnings
        let payload: InjectedPayload
        do {
            payload = try decoder.decode(InjectedPayload.self, from: data)
        } catch {
            throw PayloadError.invalid(Self.describe(error))
        }

        guard let schemaVersion = payload.schemaVersion else { throw PayloadError.missingSchemaVersion }
        guard schemaVersion.isSupported(by: runtimeVersion) else {
            throw PayloadError.unsupportedSchemaVersion(schemaVersion, runtime: runtimeVersion)
        }
        return ValidatedPayload(payload: payload, warnings: warnings.messages)
    }

    /// A readable decoding error, e.g. `body.vStack.children[2].text: missing key "value"`.
    package static func describe(_ error: Error) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined().drop { $0 == "." }.description
        }
        switch error as? DecodingError {
        case let .keyNotFound(key, context)?: return "\(path(context)): missing key \"\(key.stringValue)\""
        case let .typeMismatch(_, context)?, let .valueNotFound(_, context)?, let .dataCorrupted(context)?:
            let location = path(context)
            return (location.isEmpty ? "" : "\(location): ") + context.debugDescription
        default: return error.localizedDescription
        }
    }
}
