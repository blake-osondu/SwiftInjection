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
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    ],
    targets: [
        .target(name: "SwiftInjectionCore"),
        .target(name: "SwiftInjection", dependencies: ["SwiftInjectionCore"]),
        .testTarget(name: "SwiftInjectionCoreTests", dependencies: ["SwiftInjectionCore"]),
        .testTarget(name: "SwiftInjectionTests", dependencies: ["SwiftInjection", "ViewInspector"]),
    ]
)
