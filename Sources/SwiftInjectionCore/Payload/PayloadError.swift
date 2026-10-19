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
        case .noPayloadAvailable(let reasons): return "No usable payload: " + reasons.joined(separator: "; ")
        }
    }
}
