// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Retail",
    platforms: [.iOS("17.0")],
    products: [
        .iOSApplication(
            name: "Retail",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.swiftinjection.retail",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .gift),
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeRight, .landscapeLeft, .portraitUpsideDown(.when(deviceFamilies: [.pad]))]
        )
    ],
    dependencies: [
        .package(path: "../Packages/RetailKit"),
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Models", package: "RetailKit"),
                .product(name: "Clients", package: "RetailKit"),
                .product(name: "RemoteScreens", package: "RetailKit"),
                .product(name: "Features", package: "RetailKit"),
            ],
            path: ".",
            resources: [.process("Resources")]
        ),
    ]
)
