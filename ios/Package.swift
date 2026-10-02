// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeartRateParser",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HeartRateParser", targets: ["HeartRateParser"])
    ],
    targets: [
        .target(name: "HeartRateParser", path: "Sources/HeartRateParser"),
        .testTarget(
            name: "HeartRateParserTests",
            dependencies: ["HeartRateParser"],
            path: "Tests/HeartRateParserTests"
        )
    ]
)
