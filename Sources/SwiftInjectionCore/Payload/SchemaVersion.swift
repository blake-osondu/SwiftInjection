//
//  SchemaVersion.swift
//  SwiftInjection
//

import Foundation

/// The version of the payload format, encoded as `"major.minor"`.
///
/// A runtime accepts payloads with the same major version and a minor version at or below its own:
/// minor versions only add components, modifiers and operators; anything else is a major version.
public struct SchemaVersion: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public var major: Int
    public var minor: Int

    /// The schema this build of SwiftInjection renders.
    public static let current = SchemaVersion(major: 1, minor: 0)

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]), major >= 0, minor >= 0 else {
            return nil
        }
        self.init(major: major, minor: minor)
    }

    public func isSupported(by runtime: SchemaVersion = .current) -> Bool {
        major == runtime.major && minor <= runtime.minor
    }

    public var description: String { "\(major).\(minor)" }

    public static func < (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let version = SchemaVersion(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Schema version must be \"major.minor\", got \"\(string)\"")
        }
        self = version
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
