// swift-tools-version: 5.9

// The banking app's feature modules. Only RemoteScreens depends on SwiftInjection; every other module is
// ordinary SwiftUI and doesn't know which screens are remote.
import PackageDescription

let package = Package(
    name: "BankingKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Auth", targets: ["Auth"]),
        .library(name: "RemoteScreens", targets: ["RemoteScreens"]),
        .library(name: "Accounts", targets: ["Accounts"]),
    ],
    dependencies: [
        .package(path: "../../../../.."),
    ],
    targets: [
        .target(name: "AppCore"),
        .target(name: "Networking"),
        .target(name: "DesignSystem"),
        .target(name: "Auth", dependencies: ["Networking", "DesignSystem"]),
        .target(name: "RemoteScreens", dependencies: [
            "AppCore", "Networking", "DesignSystem",
            .product(name: "SwiftInjection", package: "SwiftInjection"),
        ]),
        .target(name: "Accounts", dependencies: ["AppCore", "Networking", "DesignSystem", "RemoteScreens"]),
        .testTarget(name: "BankingKitTests", dependencies: ["AppCore", "Networking", "Auth", "RemoteScreens", "Accounts"]),
    ]
)
