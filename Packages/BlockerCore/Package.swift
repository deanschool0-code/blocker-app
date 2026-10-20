// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BlockerCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BlockerCore", targets: ["BlockerCore"]),
    ],
    targets: [
        .target(name: "BlockerCore"),
        .testTarget(name: "BlockerCoreTests", dependencies: ["BlockerCore"]),
    ]
)
