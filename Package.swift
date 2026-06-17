// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EyeCare",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EyeCare",
            path: "Sources/EyeCare",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "EyeCareTests",
            dependencies: ["EyeCare"],
            path: "Tests/EyeCareTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
