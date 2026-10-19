//
//  PayloadLimits.swift
//  SwiftInjectionCore
//

import Foundation

/// Bounds on a payload's size and shape, enforced before it's decoded so a broken or hostile payload
/// can't exhaust memory or the decoder. The defaults are far above what real screens need.
public struct PayloadLimits: Equatable, Sendable {
    public var maxBytes: Int
    /// Maximum JSON nesting depth. Each view level uses about three (`{"vStack": {"children": [ ... ]}}`).
    public var maxDepth: Int
    /// Maximum number of JSON objects (views, modifiers, expressions, state entries...).
    public var maxObjects: Int
    public var maxScripts: Int
    public var maxScriptBytes: Int

    public static let `default` = PayloadLimits(maxBytes: 2_000_000, maxDepth: 128, maxObjects: 50_000,
                                                maxScripts: 100, maxScriptBytes: 100_000)

    public init(maxBytes: Int, maxDepth: Int, maxObjects: Int, maxScripts: Int, maxScriptBytes: Int) {
        self.maxBytes = maxBytes
        self.maxDepth = maxDepth
        self.maxObjects = maxObjects
        self.maxScripts = maxScripts
        self.maxScriptBytes = maxScriptBytes
    }

    /// Size, depth and object count, from a single pass over the raw bytes.
    func checkStructure(of data: Data) throws {
        guard data.count <= maxBytes else {
            throw PayloadError.limitExceeded("payload is \(data.count) bytes (limit \(maxBytes))")
        }
        var depth = 0, objects = 0, inString = false, escaped = false
        for byte in data {
            if inString {
                if escaped { escaped = false }
                else if byte == UInt8(ascii: "\\") { escaped = true }
                else if byte == UInt8(ascii: "\"") { inString = false }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
                if byte == UInt8(ascii: "{") { objects += 1 }
                guard depth <= maxDepth else {
                    throw PayloadError.limitExceeded("nesting is deeper than \(maxDepth) levels")
                }
                guard objects <= maxObjects else {
                    throw PayloadError.limitExceeded("more than \(maxObjects) objects")
                }
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
            default:
                break
            }
        }
    }

    func checkScripts(_ scripts: [String: String]) throws {
        guard scripts.count <= maxScripts else {
            throw PayloadError.limitExceeded("\(scripts.count) scripts (limit \(maxScripts))")
        }
        for (name, source) in scripts where source.utf8.count > maxScriptBytes {
            throw PayloadError.limitExceeded("script '\(name)' is \(source.utf8.count) bytes (limit \(maxScriptBytes))")
        }
    }
}
