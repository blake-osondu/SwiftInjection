import Foundation

/// Analytics, behind a protocol so features and tests don't depend on a vendor SDK.
public protocol Analytics: AnyObject {
    func track(_ event: String, _ properties: [String: String])
}

public final class ConsoleAnalytics: Analytics {
    public private(set) var events: [(name: String, properties: [String: String])] = []
    public init() {}
    public func track(_ event: String, _ properties: [String: String]) {
        events.append((event, properties))
        print("[analytics]", event, properties)
    }
}

/// Remote feature flags (here, in memory).
public protocol FeatureFlags: AnyObject {
    func isEnabled(_ flag: String) -> Bool
}

public final class InMemoryFeatureFlags: FeatureFlags {
    public var flags: [String: Bool]
    public init(_ flags: [String: Bool] = [:]) { self.flags = flags }
    public func isEnabled(_ flag: String) -> Bool { flags[flag] ?? false }
}
