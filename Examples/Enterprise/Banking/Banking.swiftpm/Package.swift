// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Banking",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "Banking",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.swiftinjection.banking",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .coins),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeRight, .landscapeLeft, .portraitUpsideDown(.when(deviceFamilies: [.pad]))]
        )
    ],
    dependencies: [
        .package(path: "../../../.."),
        .package(path: "../Packages/BankingKit"),
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "SwiftInjection", package: "SwiftInjection"),
                .product(name: "AppCore", package: "BankingKit"),
                .product(name: "Networking", package: "BankingKit"),
                .product(name: "Auth", package: "BankingKit"),
                .product(name: "RemoteScreens", package: "BankingKit"),
                .product(name: "Accounts", package: "BankingKit"),
            ],
            path: ".",
            resources: [.process("Resources")]
        ),
    ]
)
