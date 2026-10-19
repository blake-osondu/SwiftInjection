// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftInjection",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        /// The SwiftUI runtime that renders payloads (iOS).
        .library(name: "SwiftInjection", targets: ["SwiftInjection"]),
        /// The platform-neutral payload model: views, expressions, actions, validation and signing.
        .library(name: "SwiftInjectionCore", targets: ["SwiftInjectionCore"]),
        /// Command-line tool for publishing payloads: keygen, sign, validate (macOS).
        .executable(name: "swift-injection", targets: ["SwiftInjectionCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "SwiftInjectionCore"),
        .target(name: "SwiftInjection", dependencies: ["SwiftInjectionCore"]),
        .target(name: "SwiftInjectionTools", dependencies: ["SwiftInjectionCore"]),
        .executableTarget(name: "SwiftInjectionCLI", dependencies: [
            "SwiftInjectionTools",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "SwiftInjectionCoreTests", dependencies: ["SwiftInjectionCore"]),
        .testTarget(name: "SwiftInjectionToolsTests", dependencies: ["SwiftInjectionTools"]),
        .testTarget(name: "SwiftInjectionTests", dependencies: ["SwiftInjection", "ViewInspector"]),
    ]
)
