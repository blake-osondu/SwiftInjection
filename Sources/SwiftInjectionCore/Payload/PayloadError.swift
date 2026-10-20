//
//  PayloadError.swift
//  SwiftInjection
//

import Foundation

public enum PayloadError: Error, Equatable, CustomStringConvertible {
    case missingSchemaVersion
    case unsupportedSchemaVersion(SchemaVersion, runtime: SchemaVersion)
    /// The payload isn't valid JSON or doesn't match the schema.
    case invalid(String)
    case signatureMissing
    case signatureInvalid
    case network(String)
    case httpStatus(Int)
    /// The payload is larger, deeper or has more scripts than `PayloadLimits` allows.
    case limitExceeded(String)
    /// The loader's configuration is unsafe, e.g. a plain-HTTP URL or no signature verifier.
    case insecureConfiguration(String)
    /// Every source failed; each reason is listed in order (remote, cache, bundle).
    case noPayloadAvailable([String])

    public var description: String {
        switch self {
        case .missingSchemaVersion: return "Payload has no schemaVersion"
        case let .unsupportedSchemaVersion(version, runtime): return "Payload schema \(version) isn't supported by runtime schema \(runtime)"
        case .invalid(let reason): return "Invalid payload: \(reason)"
        case .signatureMissing: return "Payload signature is missing"
        case .signatureInvalid: return "Payload signature doesn't match any trusted key"
        case .network(let reason): return "Network error: \(reason)"
        case .httpStatus(let status): return "Server responded with HTTP \(status)"
        case .limitExceeded(let reason): return "Payload exceeds limits: \(reason)"
        case .insecureConfiguration(let reason): return "Insecure configuration: \(reason)"
        case .noPayloadAvailable(let reasons): return "No usable payload: " + reasons.joined(separator: "; ")
        }
    }
}
