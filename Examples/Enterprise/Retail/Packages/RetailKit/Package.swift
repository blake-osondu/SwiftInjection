// swift-tools-version: 5.9

// The retail app's modules, built with The Composable Architecture. Features own all state and business logic;
// most of their views are remote screens (RemoteScreens) that render the feature's state and send its actions.
import PackageDescription

let package = Package(
    name: "RetailKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Clients", targets: ["Clients"]),
        .library(name: "RemoteScreens", targets: ["RemoteScreens"]),
        .library(name: "Payment", targets: ["Payment"]),
        .library(name: "Features", targets: ["Features"]),
    ],
    dependencies: [
        .package(path: "../../../../.."),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
    ],
    targets: [
        .target(name: "Models"),
        .target(name: "Clients", dependencies: [
            "Models",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .target(name: "RemoteScreens", dependencies: [
            .product(name: "SwiftInjection", package: "SwiftInjection"),
        ]),
        .target(name: "Payment", dependencies: [
            "Models", "Clients",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .target(name: "Features", dependencies: [
            "Models", "Clients", "RemoteScreens", "Payment",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .testTarget(name: "RetailKitTests", dependencies: [
            "Models", "Clients", "Payment", "Features", "RemoteScreens",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
    ]
)
