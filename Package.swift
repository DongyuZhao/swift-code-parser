// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftParser",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftParser",
            targets: ["SwiftParser"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .target(
            name: "SwiftParser",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftParserTests",
            dependencies: ["SwiftParser"]
        ),
    ],
    swiftLanguageVersions: [.v6]
)
