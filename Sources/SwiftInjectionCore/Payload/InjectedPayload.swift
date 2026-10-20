//
//  InjectedPayload.swift
//  SwiftInjectionCore
//

import Foundation

/// A screen's payload: initial state, the root view, named views for `{"ref": ...}`, and JavaScript
/// functions callable from actions and expressions (see `ScriptRuntime`).
/// `{"state": {"count": 0}, "body": {"vStack": {...}}, "views": {"header": {...}}, "scripts": {"fmt": "(n) => ..."}}`
public struct InjectedPayload: Codable {
    /// The payload format version (see `SchemaVersion`). Required for payloads loaded by `PayloadLoader`.
    public var schemaVersion: SchemaVersion?
    /// An identifier for this payload's content, e.g. a build number or date, for logs and caching.
    public var version: String?
    @OrEmpty public var state: RuntimeValue
    public var body: InjectedView
    @OrEmpty public var views: [String: InjectedView]
    @OrEmpty public var scripts: [String: String]

    public init(schemaVersion: SchemaVersion? = .current, version: String? = nil, state: RuntimeValue = [:],
                body: InjectedView, views: [String: InjectedView] = [:], scripts: [String: String] = [:]) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.state = state
        self.body = body
        self.views = views
        self.scripts = scripts
    }
}
