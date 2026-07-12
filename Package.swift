// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RewordCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RewordCore", targets: ["RewordCore"]),
    ],
    targets: [
        .target(name: "RewordCore"),
        .testTarget(name: "RewordCoreTests", dependencies: ["RewordCore"]),
    ]
)
