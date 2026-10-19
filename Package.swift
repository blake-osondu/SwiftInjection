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
        /// Compiles a subset of SwiftUI source into payloads (macOS).
        .library(name: "SwiftInjectionCompiler", targets: ["SwiftInjectionCompiler"]),
        /// Command-line tool for publishing payloads: compile, keygen, sign, validate (macOS).
        .executable(name: "swift-injection", targets: ["SwiftInjectionCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        // Matches the Swift 6.2 toolchain; bump with the toolchain.
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    ],
    targets: [
        .target(name: "SwiftInjectionCore"),
        .target(name: "SwiftInjection", dependencies: ["SwiftInjectionCore"]),
        .target(name: "SwiftInjectionTools", dependencies: ["SwiftInjectionCore"]),
        .target(name: "SwiftInjectionCompiler", dependencies: [
            "SwiftInjectionCore",
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "SwiftOperators", package: "swift-syntax"),
        ]),
        .executableTarget(name: "SwiftInjectionCLI", dependencies: [
            "SwiftInjectionTools",
            "SwiftInjectionCompiler",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "SwiftInjectionCoreTests", dependencies: ["SwiftInjectionCore"]),
        .testTarget(name: "SwiftInjectionToolsTests", dependencies: ["SwiftInjectionTools"]),
        .testTarget(name: "SwiftInjectionCompilerTests", dependencies: ["SwiftInjectionCompiler"]),
        .testTarget(name: "SwiftInjectionTests", dependencies: ["SwiftInjection", "ViewInspector"]),
    ]
)
