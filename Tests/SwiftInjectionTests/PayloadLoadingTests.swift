import XCTest
import CryptoKit
import SwiftUI
import ViewInspector
@testable import SwiftInjection
@testable import SwiftInjectionCore

/// Serves canned responses; URLs without a response fail like an offline network.
final class StubURLProtocol: URLProtocol {
    static var responses: [URL: (status: Int, body: Data)] = [:]
    static var requested: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        Self.requested.append(url)
        guard let (status, body) = Self.responses[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

final class PayloadLoadingTests: XCTestCase {
    let url = URL(string: "https://cdn.example.com/screens/home.json")!
    var directory: URL!

    override func setUpWithError() throws {
        StubURLProtocol.responses = [:]
        StubURLProtocol.requested = []
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func payload(_ text: String, schema: String = "1.0", version: String? = nil) -> Data {
        let versionField = version.map { #""version": "\#($0)", "# } ?? ""
        return Data(#"{"schemaVersion": "\#(schema)", \#(versionField)"body": {"text": {"value": "\#(text)"}}}"#.utf8)
    }

    private func text(of payload: InjectedPayload) -> String? {
        guard case let .text(store) = payload.body, case let .literal(.string(value)) = store.value else { return nil }
        return value
    }

    private func loader(bundled: Data? = nil, verifier: PayloadVerifier? = nil, runtime: SchemaVersion = .current) throws -> PayloadLoader {
        var bundledURL: URL?
        if let bundled {
            bundledURL = directory.appendingPathComponent("bundled.json")
            try bundled.write(to: bundledURL!)
        }
        return PayloadLoader(configuration: .init(url: url, bundled: bundledURL, verifier: verifier,
                                                  allowUnsigned: verifier == nil,
                                                  cacheDirectory: directory.appendingPathComponent("cache"),
                                                  session: StubURLProtocol.session, runtimeVersion: runtime))
    }

    // MARK: schema versions

    func testSchemaVersionParsingAndCompatibility() throws {
        XCTAssertEqual(SchemaVersion("1.2"), SchemaVersion(major: 1, minor: 2))
        XCTAssertNil(SchemaVersion("1"))
        XCTAssertNil(SchemaVersion("1.x"))
        XCTAssertNil(SchemaVersion("-1.0"))

        let runtime = SchemaVersion(major: 1, minor: 2)
        XCTAssertTrue(SchemaVersion(major: 1, minor: 0).isSupported(by: runtime))
        XCTAssertTrue(SchemaVersion(major: 1, minor: 2).isSupported(by: runtime))
        XCTAssertFalse(SchemaVersion(major: 1, minor: 3).isSupported(by: runtime))
        XCTAssertFalse(SchemaVersion(major: 2, minor: 0).isSupported(by: runtime))
        XCTAssertFalse(SchemaVersion(major: 0, minor: 9).isSupported(by: runtime))

        XCTAssertEqual(String(decoding: try JSONEncoder().encode(runtime), as: UTF8.self), #""1.2""#)
    }

    // MARK: validation

    func testValidatorRequiresASupportedSchemaVersion() {
        let validator = PayloadValidator()
        XCTAssertNoThrow(try validator.validate(payload("hi"), signature: nil))
        XCTAssertThrowsError(try validator.validate(Data(#"{"body": {"empty": {}}}"#.utf8), signature: nil)) {
            XCTAssertEqual($0 as? PayloadError, .missingSchemaVersion)
        }
        XCTAssertThrowsError(try validator.validate(payload("hi", schema: "2.0"), signature: nil)) {
            XCTAssertEqual($0 as? PayloadError, .unsupportedSchemaVersion(SchemaVersion(major: 2, minor: 0), runtime: .current))
        }
        XCTAssertNoThrow(try PayloadValidator(runtimeVersion: SchemaVersion(major: 1, minor: 4)).validate(payload("hi", schema: "1.3"), signature: nil))
    }

    func testValidatorDescribesWhereAPayloadIsInvalid() {
        let data = Data(#"{"schemaVersion": "1.0", "body": {"vStack": {"children": [{"text": {}}]}}}"#.utf8)
        XCTAssertThrowsError(try PayloadValidator().validate(data, signature: nil)) {
            XCTAssertEqual($0 as? PayloadError, .invalid(#"body.vStack.children[0].text: missing key "value""#))
        }
    }

    // MARK: forward compatibility

    func testUnknownComponentsAndModifiersAreSkippedWithWarnings() throws {
        let data = Data(#"""
        {"schemaVersion": "1.0", "body": {"vStack": {"children": [
          {"text": {"value": "kept", "modifiers": [{"bold": {}}, {"sparkle": {"intensity": 3}}]}},
          {"carousel": {"pages": []}}
        ]}}}
        """#.utf8)
        let validated = try PayloadValidator().validate(data, signature: nil)
        XCTAssertEqual(validated.warnings, [
            "Skipped unknown modifier 'sparkle' at .body.vStack.children[0].text.modifiers[1]",
            "Skipped unknown component 'carousel' at .body.vStack.children[1]",
        ])

        guard case let .vStack(stack) = validated.payload.body, case let .text(text) = stack.children[0] else { return XCTFail() }
        XCTAssertEqual(text.modifiers.count, 1)
        guard case .unsupported(name: "carousel", content: ["pages": []]) = stack.children[1] else { return XCTFail("\(stack.children[1])") }

        // It re-encodes unchanged, and renders as nothing (reported).
        let reencoded = String(decoding: try JSONEncoder().encode(stack.children[1]), as: UTF8.self)
        XCTAssertEqual(reencoded, #"{"carousel":{"pages":[]}}"#)
        let store = StateStore()
        var errors: [String] = []
        store.onError = { errors.append("\($0)") }
        let screen = InjectedScreen(store: store, payload: validated.payload)
        XCTAssertEqual(try screen.inspect().findAll(ViewType.Text.self).map { try $0.string() }, ["kept"])
        XCTAssertEqual(Set(errors), [PayloadError.invalid("Component 'carousel' isn't supported by this version").description])
    }

    func testKnownModifierWithBadArgumentsStillFails() {
        let data = Data(#"{"schemaVersion": "1.0", "body": {"text": {"value": "x", "modifiers": [{"cornerRadius": {}}]}}}"#.utf8)
        XCTAssertThrowsError(try PayloadValidator().validate(data, signature: nil))
    }

    func testKnownModifierNamesMatchEveryCase() throws {
        // The fixture holds one of every modifier case.
        let fixture = try JSONDecoder().decode([[String: RuntimeValue]].self, from: Data(ModifierTests.allModifiersJSON.utf8))
        XCTAssertEqual(Set(fixture.flatMap(\.keys)), InjectedModifier.knownNames)
    }

    // MARK: signatures

    func testSignatureVerification() throws {
        let key = Curve25519.Signing.PrivateKey()
        let oldKey = Curve25519.Signing.PrivateKey()
        let verifier = PayloadVerifier(publicKeys: [oldKey.publicKey, key.publicKey])
        let data = payload("signed")
        let signature = try PayloadSigner.signature(for: data, using: key)

        XCTAssertNoThrow(try verifier.verify(data, signature: signature))
        XCTAssertNoThrow(try verifier.verify(data, signature: try PayloadSigner.signature(for: data, using: oldKey)))
        XCTAssertNoThrow(try verifier.verify(data, signature: signature + Data("\n".utf8)))

        XCTAssertThrowsError(try verifier.verify(payload("tampered"), signature: signature)) { XCTAssertEqual($0 as? PayloadError, .signatureInvalid) }
        XCTAssertThrowsError(try verifier.verify(data, signature: try PayloadSigner.signature(for: data, using: .init()))) {
            XCTAssertEqual($0 as? PayloadError, .signatureInvalid)
        }
        XCTAssertThrowsError(try PayloadValidator(verifier: verifier).validate(data, signature: nil)) {
            XCTAssertEqual($0 as? PayloadError, .signatureMissing)
        }

        let base64 = key.publicKey.rawRepresentation.base64EncodedString()
        XCTAssertNoThrow(try PayloadVerifier(base64PublicKeys: [base64]).verify(data, signature: signature))
    }

    // MARK: loader

    func testLoadsRemoteAndCachesIt() async throws {
        StubURLProtocol.responses[url] = (200, payload("remote"))
        let loader = try loader()
        let loaded = try await loader.load()
        XCTAssertEqual(loaded.source, .remote)
        XCTAssertEqual(text(of: loaded.payload), "remote")
        XCTAssertEqual(try Data(contentsOf: loader.cachedPayloadURL), payload("remote"))
    }

    func testFallsBackToCacheWhenOffline() async throws {
        StubURLProtocol.responses[url] = (200, payload("first"))
        let loader = try loader(bundled: payload("bundled"))
        _ = try await loader.load()

        StubURLProtocol.responses = [:]
        let loaded = try await loader.load()
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(text(of: loaded.payload), "first")
        guard case .network? = loaded.skipped.first else { return XCTFail("\(loaded.skipped)") }
    }

    func testFallsBackToBundleOnServerError() async throws {
        StubURLProtocol.responses[url] = (500, Data("oops".utf8))
        let loaded = try await loader(bundled: payload("bundled")).load()
        XCTAssertEqual(loaded.source, .bundle)
        XCTAssertEqual(text(of: loaded.payload), "bundled")
        XCTAssertEqual(loaded.skipped.first, .httpStatus(500))
    }

    func testInvalidRemotePayloadDoesNotReplaceTheCache() async throws {
        let loader = try loader()
        StubURLProtocol.responses[url] = (200, payload("good"))
        _ = try await loader.load()

        StubURLProtocol.responses[url] = (200, payload("too new", schema: "9.0"))
        let loaded = try await loader.load()
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(text(of: loaded.payload), "good")
        XCTAssertEqual(loaded.skipped, [.unsupportedSchemaVersion(SchemaVersion(major: 9, minor: 0), runtime: .current)])
    }

    func testSignedLoadingRejectsTamperedCache() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let data = payload("signed")
        StubURLProtocol.responses[url] = (200, data)
        StubURLProtocol.responses[url.appendingPathExtension("sig")] = (200, try PayloadSigner.signature(for: data, using: key))
        let loader = try loader(bundled: payload("bundled"), verifier: PayloadVerifier(publicKeys: [key.publicKey]))

        let remote = try await loader.load()
        XCTAssertEqual(remote.source, .remote)
        XCTAssertTrue(StubURLProtocol.requested.contains(url.appendingPathExtension("sig")))

        // Someone edits the cached payload on disk; it no longer matches its signature.
        try payload("evil").write(to: loader.cachedPayloadURL)
        StubURLProtocol.responses = [:]
        let fallback = try loader.loadLocal()
        XCTAssertEqual(fallback.source, .bundle)
        XCTAssertEqual(fallback.skipped, [.signatureInvalid])
    }

    func testUnsignedRemoteIsRejectedWhenVerifying() async throws {
        StubURLProtocol.responses[url] = (200, payload("unsigned"))
        let loaded = try await loader(bundled: payload("bundled"), verifier: PayloadVerifier(publicKeys: [Curve25519.Signing.PrivateKey().publicKey])).load()
        XCTAssertEqual(loaded.source, .bundle)
        // No signature is served at home.json.sig, so the remote payload is never accepted.
        guard case .network? = loaded.skipped.first else { return XCTFail("\(loaded.skipped)") }
        XCTAssertTrue(StubURLProtocol.requested.contains(url.appendingPathExtension("sig")))
    }

    func testReportsEveryReasonWhenNothingLoads() async throws {
        do {
            _ = try await loader().load()
            XCTFail("Expected failure")
        } catch let PayloadError.noPayloadAvailable(reasons) {
            XCTAssertEqual(reasons.count, 3)
            XCTAssertTrue(reasons[0].hasPrefix("Network error"), reasons[0])
            XCTAssertEqual(reasons[1], "Invalid payload: No cached payload")
            XCTAssertEqual(reasons[2], "Invalid payload: No bundled payload configured")
        }
    }

    // MARK: remote screen model

    @MainActor
    func testModelShowsRemoteWhenNothingIsCached() async throws {
        StubURLProtocol.responses[url] = (200, payload("remote", version: "2"))
        let model = RemotePayloadModel(loader: try loader())
        await model.start()
        XCTAssertEqual(model.source, .remote)
        XCTAssertEqual(model.payload?.version, "2")
    }

    @MainActor
    func testUpdatePolicies() async throws {
        let loader = try loader()
        StubURLProtocol.responses[url] = (200, payload("v1", version: "1"))
        _ = try await loader.load()
        StubURLProtocol.responses[url] = (200, payload("v2", version: "2"))

        let nextLaunch = RemotePayloadModel(loader: loader, updatePolicy: .nextLaunch)
        await nextLaunch.start()
        XCTAssertEqual(nextLaunch.payload?.version, "1")
        XCTAssertEqual(nextLaunch.source, .cache)
        XCTAssertEqual(try loader.loadLocal().payload.version, "2")  // picked up next time

        StubURLProtocol.responses[url] = (200, payload("v3", version: "3"))
        let immediately = RemotePayloadModel(loader: loader, updatePolicy: .immediately)
        await immediately.start()
        XCTAssertEqual(immediately.payload?.version, "3")
        XCTAssertEqual(immediately.source, .remote)
        XCTAssertEqual(immediately.generation, 2, "cached payload shown, then rebuilt for the remote one")
    }

    @MainActor
    func testHostStateIsInjectedAndKeptLive() async throws {
        StubURLProtocol.responses[url] = (200, payload("remote", version: "2"))
        struct Cart: Codable, Equatable { var items: [String]; var total: Double }
        let model = RemotePayloadModel(loader: try loader(),
                                       hostState: ["cart": try RuntimeValue(encoding: Cart(items: ["Mug"], total: 12.5)), "user.name": "Ada"])
        await model.start()
        let store = try XCTUnwrap(model.store)
        XCTAssertEqual(try store.value(at: ["cart"])?.decode(Cart.self), Cart(items: ["Mug"], total: 12.5))
        XCTAssertEqual(store.value(at: ["user", "name"]), "Ada")

        model.setHostState(["cart": try RuntimeValue(encoding: Cart(items: ["Mug", "Tee"], total: 40)), "user.name": "Ada"])
        XCTAssertEqual(try store.value(at: ["cart"])?.decode(Cart.self), Cart(items: ["Mug", "Tee"], total: 40))
    }

    @MainActor
    func testModelReportsErrorWhenNothingLoads() async throws {
        let model = RemotePayloadModel(loader: try loader())
        await model.start()
        XCTAssertNil(model.payload)
        guard case .network? = model.error else { return XCTFail("\(String(describing: model.error))") }
    }

    // MARK: secure defaults

    func testUnsignedLoadingIsRefusedByDefault() async throws {
        StubURLProtocol.responses[url] = (200, payload("remote"))
        let bundled = directory.appendingPathComponent("bundled.json")
        try payload("bundled").write(to: bundled)
        let loader = PayloadLoader(configuration: .init(url: url, bundled: bundled,
                                                        cacheDirectory: directory.appendingPathComponent("cache"),
                                                        session: StubURLProtocol.session))
        let loaded = try await loader.load()
        XCTAssertEqual(loaded.source, .bundle)  // bundled payloads are trusted by the app's own signature
        XCTAssertEqual(loaded.skipped.first, .insecureConfiguration("no signature verifier (set allowUnsigned for local development)"))
        XCTAssertTrue(StubURLProtocol.requested.isEmpty, "nothing should be fetched with an insecure configuration")
    }

    func testAllowUnsignedOptsOutWithAWarning() async throws {
        var logs: [String] = []
        let previous = PayloadLoader.log
        PayloadLoader.log = { logs.append($0) }
        defer { PayloadLoader.log = previous }

        StubURLProtocol.responses[url] = (200, payload("remote"))
        let loader = PayloadLoader(configuration: .init(url: url, allowUnsigned: true,
                                                        cacheDirectory: directory.appendingPathComponent("cache"),
                                                        session: StubURLProtocol.session))
        let loaded = try await loader.load()
        XCTAssertEqual(loaded.source, .remote)
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(logs[0].contains("unsigned"), logs[0])
    }

    func testPlainHTTPIsRefusedUnlessAllowed() async throws {
        let http = URL(string: "http://192.168.1.10:8080/home.json")!
        StubURLProtocol.responses[http] = (200, payload("over http"))
        let key = Curve25519.Signing.PrivateKey()
        StubURLProtocol.responses[http.appendingPathExtension("sig")] = (200, try PayloadSigner.signature(for: payload("over http"), using: key))
        let verifier = PayloadVerifier(publicKeys: [key.publicKey])

        let refused = PayloadLoader(configuration: .init(url: http, verifier: verifier,
                                                         cacheDirectory: directory.appendingPathComponent("a"), session: StubURLProtocol.session))
        do {
            _ = try await refused.loadRemote()
            XCTFail("Expected an insecure configuration error")
        } catch {
            XCTAssertEqual(error as? PayloadError, .insecureConfiguration("http://192.168.1.10:8080/home.json isn't HTTPS (set allowInsecureHTTP for local development)"))
        }

        let allowed = PayloadLoader(configuration: .init(url: http, verifier: verifier, allowInsecureHTTP: true,
                                                         cacheDirectory: directory.appendingPathComponent("b"), session: StubURLProtocol.session))
        let loaded = try await allowed.loadRemote()
        XCTAssertEqual(text(of: loaded.payload), "over http")
    }

    // MARK: limits

    func testLimitsAreEnforcedBeforeDecoding() {
        func rejects(_ data: Data, _ limits: PayloadLimits, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertThrowsError(try PayloadValidator(limits: limits).validate(data, signature: nil), file: file, line: line) {
                guard case .limitExceeded? = $0 as? PayloadError else { return XCTFail("\($0)", file: file, line: line) }
            }
        }
        var tight = PayloadLimits.default
        tight.maxBytes = 50
        rejects(payload("this payload is longer than fifty bytes"), tight)

        tight = .default
        tight.maxDepth = 10
        let deep = String(repeating: #"{"group": {"children": ["#, count: 5) + #"{"empty": {}}"# + String(repeating: "]}}", count: 5)
        rejects(Data(#"{"schemaVersion": "1.0", "body": \#(deep)}"#.utf8), tight)

        tight = .default
        tight.maxObjects = 3
        rejects(Data(#"{"schemaVersion": "1.0", "body": {"vStack": {"children": [{"empty": {}}, {"empty": {}}]}}}"#.utf8), tight)

        tight = .default
        tight.maxScriptBytes = 10
        rejects(Data(#"{"schemaVersion": "1.0", "scripts": {"long": "(a, b) => a + b + 1"}, "body": {"empty": {}}}"#.utf8), tight)
    }

    func testDepthScanIgnoresBracketsInsideStrings() throws {
        var limits = PayloadLimits.default
        limits.maxDepth = 6
        let data = Data(#"{"schemaVersion": "1.0", "body": {"text": {"value": "[[[[{{{{ \"quoted\" ]]]] }}}}"}}}"#.utf8)
        XCTAssertNoThrow(try PayloadValidator(limits: limits).validate(data, signature: nil))
    }

    func testHugeNestingFailsCleanlyInsteadOfCrashing() {
        let data = Data((#"{"schemaVersion": "1.0", "body": "# + String(repeating: "[", count: 100_000)).utf8)
        XCTAssertThrowsError(try PayloadValidator().validate(data, signature: nil)) {
            XCTAssertEqual($0 as? PayloadError, .limitExceeded("nesting is deeper than 128 levels"))
        }
    }
}
