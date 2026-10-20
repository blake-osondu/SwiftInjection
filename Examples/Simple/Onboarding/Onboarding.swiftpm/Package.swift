// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Onboarding",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "Onboarding",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.swiftinjection.onboarding",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .sparkle),
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeRight, .landscapeLeft, .portraitUpsideDown(.when(deviceFamilies: [.pad]))]
        )
    ],
    dependencies: [
        .package(path: "../../../.."),
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [.product(name: "SwiftInjection", package: "SwiftInjection")],
            path: ".",
            resources: [.process("Resources")]
        ),
    ]
)
