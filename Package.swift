// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Perch",
    // iOS for PerchKit only: the iOS app (iOS/project.yml) uses it as a package.
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "PerchKit", targets: ["PerchKit"]),
    ],
    dependencies: [
        // Auto updates from the appcast on the project site.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "PerchKit"),
        .executableTarget(
            name: "Perch",
            dependencies: ["PerchKit", .product(name: "Sparkle", package: "Sparkle")],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "PerchKitTests", dependencies: ["PerchKit"]),
    ]
)
