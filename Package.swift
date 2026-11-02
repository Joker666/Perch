// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DoFloaty",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "DoFloatyKit"),
        .executableTarget(
            name: "DoFloaty",
            dependencies: ["DoFloatyKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "DoFloatyKitTests", dependencies: ["DoFloatyKit"]),
    ]
)
