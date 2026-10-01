// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TopNotchCompat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TopNotchCompat", targets: ["TopNotchCompat"]),
        .library(name: "TopNotchCompatCore", targets: ["TopNotchCompatCore"]),
    ],
    targets: [
        .target(name: "TopNotchCompatCore"),
        .executableTarget(
            name: "TopNotchCompat",
            dependencies: ["TopNotchCompatCore"]
        ),
        .testTarget(
            name: "TopNotchCompatCoreTests",
            dependencies: ["TopNotchCompatCore"]
        ),
    ]
)
