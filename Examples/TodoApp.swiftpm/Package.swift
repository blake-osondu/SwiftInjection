// swift-tools-version: 5.9

// An app package: open it in Xcode (or Swift Playgrounds) and run it on a simulator.
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "TodoApp",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "TodoApp",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.swiftinjection.todoapp",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .checkmark),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeRight, .landscapeLeft, .portraitUpsideDown(.when(deviceFamilies: [.pad]))]
        )
    ],
    dependencies: [
        .package(path: "../.."),
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
